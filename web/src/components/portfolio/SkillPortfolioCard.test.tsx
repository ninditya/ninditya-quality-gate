import { render, screen, within } from "@testing-library/react";
import SkillPortfolioCard from "./SkillPortfolioCard";
import contract from "@contracts/portfolio.json";
import type { PortfolioSkill } from "@/types";

const [rated, unrated] = contract.portfolio.skills as unknown as PortfolioSkill[];

describe("SkillPortfolioCard against the API contract", () => {
  it("shows the AI level for a rated skill", () => {
    render(<SkillPortfolioCard skill={rated} onOverrideSaved={() => {}} />);

    expect(screen.getByText("L3")).toBeInTheDocument();
  });

  it("shows a skill that was not assessed as not assessed, never as L1 [AC-PF-01]", () => {
    render(<SkillPortfolioCard skill={unrated} onOverrideSaved={() => {}} />);

    expect(screen.getByText("Not assessed")).toBeInTheDocument();
    expect(screen.queryByText("L1")).not.toBeInTheDocument();
  });

  it("shows a quote the candidate never said apart from the evidence, and says so [AC-PF-07]", () => {
    render(<SkillPortfolioCard skill={rated} onOverrideSaved={() => {}} />);
    const [said] = rated.evidence;
    const [invented] = rated.unverified_evidence;

    const evidence = within(screen.getByTestId("evidence"));
    expect(evidence.getByText(new RegExp(said))).toBeInTheDocument();
    expect(evidence.queryByText(new RegExp(invented))).not.toBeInTheDocument();

    const unverified = within(screen.getByTestId("unverified-evidence"));
    expect(unverified.getByText("Not found in the transcript")).toBeInTheDocument();
    expect(unverified.getByText(new RegExp(invented))).toBeInTheDocument();
  });

  it("shows no such section when every quote was found", () => {
    render(<SkillPortfolioCard skill={{ ...rated, unverified_evidence: [] }} onOverrideSaved={() => {}} />);

    expect(screen.queryByTestId("unverified-evidence")).not.toBeInTheDocument();
  });
});
