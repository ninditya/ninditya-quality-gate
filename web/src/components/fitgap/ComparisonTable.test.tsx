import { render, screen, within } from "@testing-library/react";
import ComparisonTable from "./ComparisonTable";
import contract from "@contracts/fit_gap_report.json";
import type { SkillComparison } from "@/types";

// Renders the exact payload the API contract promises (contracts/fit_gap_report.json).
// The API suite asserts the real response has this shape; this asserts the
// screen tells the truth about it.
const comparisons = contract.report.skill_comparisons as SkillComparison[];

function row(label: string) {
  return within(screen.getByText(label).closest("tr")!);
}

describe("ComparisonTable against the API contract", () => {
  it("shows the level the vacancy requires [AC-FG-05]", () => {
    render(<ComparisonTable comparisons={comparisons} />);

    const cells = row("React / Frontend Development").getAllByRole("cell");
    expect(cells[1]).toHaveTextContent("L3");
    expect(cells[2]).toHaveTextContent("L4");
  });

  it("marks a level that came from a human override [AC-FG-03]", () => {
    render(<ComparisonTable comparisons={comparisons} />);

    expect(row("React / Frontend Development").getAllByRole("cell")[2]).toHaveTextContent("✏");
    expect(row("Communication").getAllByRole("cell")[2]).not.toHaveTextContent("✏");
  });

  it("shows an unrated skill as not assessed, with no level [AC-FG-02]", () => {
    render(<ComparisonTable comparisons={comparisons} />);

    const cells = row("System Design").getAllByRole("cell");
    expect(cells[1]).toHaveTextContent("L2");
    expect(cells[2]).toHaveTextContent("—");
    expect(cells[3]).toHaveTextContent("Not assessed");
  });
});
