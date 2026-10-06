import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import LevelRadio from "./LevelRadio";

// Every skill row on the vacancy and assessment forms has its own level picker.
describe("LevelRadio", () => {
  it("changes only its own skill when a level label is clicked [AC-VAC-02]", async () => {
    const first = vi.fn();
    const second = vi.fn();
    render(
      <>
        <div data-testid="skill-1"><LevelRadio value={3} onChange={first} /></div>
        <div data-testid="skill-2"><LevelRadio value={3} onChange={second} /></div>
      </>
    );

    await userEvent.click(within(screen.getByTestId("skill-2")).getByText("L5"));

    expect(second).toHaveBeenCalledWith(5);
    expect(first).not.toHaveBeenCalled();
  });
});
