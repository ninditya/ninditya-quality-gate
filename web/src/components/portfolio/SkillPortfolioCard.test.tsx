import { render, screen } from "@testing-library/react";
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
});
