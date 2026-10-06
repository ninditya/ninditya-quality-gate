# frozen_string_literal: true

module Portfolios
  # N10: Generates a structured skill portfolio from the full transcript
  # and final coverage map using Gemini Pro.
  # Runs post-session as a background job.
  class Generator
    def initialize(session:, gemini_client: nil)
      @session = session
      @gemini_client = gemini_client || Gemini::HttpClient.new(
        model:   ENV.fetch('GEMINI_PRO_MODEL', 'gemini-2.0-pro-001'),
        timeout: 180  # up to 3 minutes for large transcripts
      )
    end

    NOT_DISCUSSED = 'Not assessed: this skill was not discussed in the interview.'
    NOT_RATEABLE  = 'Not assessed: the interview did not produce enough evidence to rate this skill.'

    # Returns the Portfolio record with skills populated.
    #
    # The model's answer is treated as untrusted input. What is stored is decided
    # here: which skills exist (the assessment's), whether a skill was assessed
    # at all (the coverage map), and how confident the rating is (the PRD rule).
    # The model only supplies the level, the evidence and the summary.
    def call
      portfolio = @session.portfolio || @session.create_portfolio!(
        candidate_id:      @session.candidate_id,
        generation_status: 'pending'
      )

      portfolio.update!(generation_status: 'generating')

      # No candidate speech means there is nothing to rate, so the model is not
      # asked to: it would answer anyway.
      ratings = candidate_spoke? ? parse(@gemini_client.generate_content(build_prompt, temperature: 0.2)) : {}

      # All or nothing. A failure part-way must not leave the portfolio with
      # half its skills, or with the previous ratings and overrides destroyed.
      Portfolio.transaction do
        save_skills(portfolio, ratings)
        portfolio.update!(generation_status: 'complete', generated_at: Time.current, generation_error: nil)
      end

      Rails.logger.info("[N10] Portfolio generated for session #{@session.id}")
      portfolio
    rescue => e
      portfolio&.reload&.update!(generation_status: 'failed', generation_error: e.message)
      Rails.logger.error("[N10] Portfolio generation failed for session #{@session.id}: #{e.class} #{e.message}")
      raise
    end

    private

    def build_prompt
      assessment       = @session.assessment
      configured_skills = assessment.assessment_skills.order(:display_order)
      coverage_maps     = @session.coverage_maps.order(:id)
      turns             = @session.transcript_turns.ordered

      skills_text = configured_skills.map { |s| skill_definition_block(s) }.join("\n\n")

      coverage_json = {
        skills:     coverage_maps.reject(&:is_discovered).map { |m| coverage_json(m) },
        discovered: coverage_maps.select(&:is_discovered).map { |m| coverage_json(m) }
      }.to_json

      transcript_text = turns.map { |t| "[#{t.speaker.upcase}]: #{t.text}" }.join("\n")

      <<~PROMPT
        You are evaluating a completed skills assessment interview to produce a structured skill portfolio.

        ROLE BEING ASSESSED: #{assessment.name}

        SKILL DEFINITIONS AND BEHAVIORAL ANCHORS:
        #{skills_text}

        UNIVERSAL L1-L5 ANCHORS (use for discovered skills):
        L1 — Executes with explicit guidance and close review. Understands conceptually but cannot apply independently.
        L2 — Executes independently on routine scope. Uses known patterns. Handles common cases but not edge cases.
        L3 — Executes complex, ambiguous scope. Makes tradeoffs. Handles edge cases. Can teach L1-L2.
        L4 — Defines standards and creates reusable systems. Resolves systemic problems. Cross-team impact.
        L5 — Org-level authority. Shapes how the skill is practiced. Rare.

        FINAL COVERAGE MAP:
        #{coverage_json}

        FULL INTERVIEW TRANSCRIPT:
        #{transcript_text}

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        TASK
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        For EACH skill in the coverage map (both configured and discovered):

        1. FIND THE EVIDENCE
           Read all transcript turns where this skill was discussed.
           Identify the 2-3 most revealing quotes from the CANDIDATE (not the AI).
           A quote is revealing if it shows HOW they think, not just WHAT they know.

        2. ASSIGN A LEVEL
           Compare the candidate's actual behavior to the L1-L5 anchors.
           Assign the highest level where you see CONSISTENT evidence, not just one strong moment.
           If evidence is mixed (mostly L2 with one L3 moment), assign L2.
           If a skill was not discussed, or the transcript holds no evidence for it, set "level" to null.
           Never guess a level: null is the correct answer when you cannot tell.

        3. WRITE THE COMPETENCY SUMMARY
           2-3 sentences. Focus on patterns, not individual answers.
           What does this person reliably do at this skill? What's the ceiling? What's missing?

        4. ASSIGN CONFIDENCE
           high — probe_count >= 3 AND state = covered
           medium — probe_count = 2 OR state = partial
           low — probe_count <= 1 OR state = initiated

        OUTPUT (JSON only, no prose):
        {
          "configured_skills": [
            {
              "skill_id": "sk-eng-001",
              "skill_label": "React / Frontend Development",
              "level": 3,
              "confidence": "high",
              "evidence": ["quote 1", "quote 2", "quote 3"],
              "competency_summary": "2-3 sentence summary"
            }
          ],
          "discovered_skills": [
            {
              "skill_label": "Micro-frontend Architecture",
              "level": 2,
              "confidence": "low",
              "evidence": ["quote 1"],
              "competency_summary": "2-3 sentence summary"
            }
          ]
        }
      PROMPT
    end

    def skill_definition_block(skill)
      lines = ["━━━━━━━━━━━━━━━"]
      lines << "SKILL: #{skill.skill_label} (#{skill.skill_id || 'custom'})"
      lines << "SCOPE: #{skill.scope_include}" if skill.scope_include.present?
      lines << ""
      lines << "L1 — #{skill.l1_anchor}"
      lines << "L2 — #{skill.l2_anchor}"
      lines << "L3 — #{skill.l3_anchor}"
      lines << "L4 — #{skill.l4_anchor}"
      lines << "L5 — #{skill.l5_anchor}"
      lines.join("\n")
    end

    def coverage_json(map)
      {
        id:          map.skill_id || map.skill_label.downcase.gsub(/\s+/, '-'),
        label:       map.skill_label,
        state:       map.state,
        probe_count: map.probe_count,
        is_discovered: map.is_discovered
      }
    end

    def candidate_spoke?
      @session.transcript_turns.where(speaker: 'candidate').exists?
    end

    def parse(response)
      data = response.is_a?(Hash) ? response : JSON.parse(response)
      raise ArgumentError, 'Model returned no skill ratings object' unless data.is_a?(Hash)

      data
    end

    def save_skills(portfolio, ratings)
      # Destroy existing skills (idempotent regeneration). Inside the caller's
      # transaction, so a failure below restores them and their overrides.
      portfolio.portfolio_skills.destroy_all

      maps       = @session.coverage_maps.to_a
      configured = @session.assessment.assessment_skills.order(:display_order).to_a

      # Every configured skill gets a row, whether or not the model mentioned it.
      configured.each do |skill|
        create_skill(
          portfolio,
          skill_id: skill.skill_id, label: skill.skill_label, discovered: false,
          map:    find_entry(maps.reject(&:is_discovered), skill.skill_id, skill.skill_label, :skill_id, :skill_label),
          rating: find_entry(Array(ratings['configured_skills']), skill.skill_id, skill.skill_label,
                             'skill_id', 'skill_label')
        )
      end

      # A discovered skill is one the coverage map tracked during the interview.
      # One the model introduces only now has no coverage behind it and is dropped.
      Array(ratings['discovered_skills']).each do |rating|
        label = rating['skill_label'].to_s.strip
        map   = find_entry(maps.select(&:is_discovered), nil, label, :skill_id, :skill_label)
        next if map.nil? || configured.any? { |skill| same_label?(skill.skill_label, label) }

        create_skill(portfolio, skill_id: nil, label: map.skill_label, discovered: true, map: map, rating: rating)
      end
    end

    def create_skill(portfolio, skill_id:, label:, discovered:, map:, rating:)
      level = rated_level(map, rating)

      portfolio.portfolio_skills.create!(
        skill_id:           skill_id,
        skill_label:        label,
        is_discovered:      discovered,
        ai_level:           level,
        ai_confidence:      confidence_for(map, level),
        evidence:           level ? Array(rating['evidence']).map(&:to_s).reject(&:blank?).first(3) : [],
        competency_summary: level ? rating['competency_summary'] : (discussed?(map) ? NOT_RATEABLE : NOT_DISCUSSED)
      )
    end

    # A level is stored only when the skill was actually discussed AND the model
    # returned a usable level. Anything else is nil ("not assessed"), never a
    # default: the old `to_i.clamp(1, 5)` turned a missing rating into L1.
    def rated_level(map, rating)
      return nil unless discussed?(map) && rating

      level = rating['level']
      level = Integer(level, exception: false) if level.is_a?(String)
      level = level.to_i if level.is_a?(Float) && level == level.to_i
      level.is_a?(Integer) && (1..5).cover?(level) ? level : nil
    end

    def discussed?(map)
      map.present? && map.state != 'not_yet' && map.probe_count.positive?
    end

    # PRD 01 section 5, evaluated here rather than requested from the model:
    #   high   — probe_count >= 3 AND state = covered
    #   medium — probe_count = 2 OR state = partial
    #   low    — everything else
    def confidence_for(map, level)
      return 'low' if level.nil? || map.nil?
      return 'high' if map.probe_count >= 3 && map.state == 'covered'
      return 'medium' if map.probe_count == 2 || map.state == 'partial'

      'low'
    end

    # Matches by skill id when both sides have one, otherwise by label.
    def find_entry(entries, skill_id, label, id_key, label_key)
      read = ->(entry, key) { entry.respond_to?(:[]) && !entry.is_a?(ActiveRecord::Base) ? entry[key] : entry.public_send(key) }

      (skill_id.present? && entries.find { |e| read.call(e, id_key).to_s == skill_id.to_s }) ||
        entries.find { |e| same_label?(read.call(e, label_key), label) }
    end

    def same_label?(left, right)
      left.to_s.strip.casecmp?(right.to_s.strip)
    end
  end
end
