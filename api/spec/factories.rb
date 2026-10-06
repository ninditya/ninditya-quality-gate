# frozen_string_literal: true

# Tenant-scoped records always get an explicit tenant here. Specs run outside a
# request, where there is no ambient tenant to fall back on.
FactoryBot.define do
  factory :organization do
    sequence(:name)       { |n| "Org #{n}" }
    sequence(:scheme)     { |n| "org-#{n}" }
    sequence(:identifier) { |n| "org-#{n}" }
    sequence(:host)       { |n| "org-#{n}.example.test" }
  end

  factory :user do
    sequence(:email) { |n| "assessor#{n}@example.test" }
    password { 'correct-horse-battery' }
    role     { 'admin' }
  end

  factory :assessment do
    transient { organization { association(:organization) } }

    tenant_id      { organization.id }
    created_by     { 1 }
    name           { 'Senior Frontend Engineer' }
    time_limit_min { 45 }

    trait :with_skills do
      after(:create) do |assessment|
        create(:assessment_skill, assessment: assessment, skill_id: 'sk-eng-001',
                                  skill_label: 'React / Frontend Development', display_order: 0)
        create(:assessment_skill, assessment: assessment, skill_id: nil, is_custom: true,
                                  skill_label: 'Communication', display_order: 1)
        create(:assessment_skill, assessment: assessment, skill_id: nil, is_custom: true,
                                  skill_label: 'System Design', display_order: 2, expected_level: 2)
      end
    end
  end

  factory :assessment_skill do
    assessment
    skill_label    { 'React / Frontend Development' }
    l1_anchor      { 'Needs close guidance' }
    l2_anchor      { 'Independent on routine scope' }
    l3_anchor      { 'Handles ambiguous scope' }
    l4_anchor      { 'Defines standards' }
    l5_anchor      { 'Org-level authority' }
    expected_level { 3 }
    display_order  { 0 }
  end

  factory :session do
    assessment
    tenant_id { assessment.tenant_id }
    candidate_name { 'Ahmad Rizky' }

    trait :active do
      status     { 'active' }
      started_at { 10.minutes.ago }
    end

    trait :ended do
      status           { 'ended' }
      end_reason       { 'manual_assessor' }
      started_at       { 40.minutes.ago }
      ended_at         { 2.minutes.ago }
      duration_seconds { 2280 }
    end
  end

  factory :coverage_map do
    session
    skill_label { 'React / Frontend Development' }
    state       { 'not_yet' }
    probe_count { 0 }
  end

  factory :transcript_turn do
    session
    sequence(:turn_number) { |n| n }
    speaker { 'candidate' }
    text    { 'We moved real-time data into local component state with useRef.' }
  end

  factory :portfolio do
    session
    generation_status { 'complete' }
    generated_at      { Time.current }
  end

  factory :portfolio_skill do
    portfolio
    skill_label        { 'React / Frontend Development' }
    ai_level           { 3 }
    ai_confidence      { 'high' }
    evidence           { ['"We moved real-time data into local component state"'] }
    competency_summary { 'Handles complex state management with clear tradeoff reasoning.' }
  end

  factory :vacancy do
    transient { organization { association(:organization) } }

    tenant_id  { organization.id }
    created_by { 1 }
    role_title { 'Senior Frontend Engineer' }
  end

  factory :vacancy_skill do
    vacancy
    skill_label    { 'React / Frontend Development' }
    expected_level { 3 }
  end
end
