import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import PortfolioPage from "./PortfolioPage";
import { sessionsApi } from "@/services/sessions";
import { vacanciesApi } from "@/services/vacancies";
import contract from "@contracts/portfolio.json";

vi.mock("@/services/sessions", () => ({
  sessionsApi: { getPortfolio: vi.fn(), get: vi.fn() },
}));
vi.mock("@/services/vacancies", () => ({ vacanciesApi: { list: vi.fn() } }));
vi.mock("@/services/portfolios", () => ({ portfoliosApi: {} }));

function openPortfolio(portfolio: unknown) {
  vi.mocked(sessionsApi.getPortfolio).mockResolvedValue({ data: { portfolio } } as never);
  vi.mocked(sessionsApi.get).mockResolvedValue({ data: { session: { candidate_name: "Ahmad Rizky" } } } as never);
  vi.mocked(vacanciesApi.list).mockResolvedValue({ data: { vacancies: [] } } as never);
  render(
    <MemoryRouter initialEntries={["/assessments/4/sessions/21/portfolio"]}>
      <Routes>
        <Route path="/assessments/:id/sessions/:sessionId/portfolio" element={<PortfolioPage />} />
      </Routes>
    </MemoryRouter>
  );
}

// The ratings on this page were generated from the transcript. If part of the
// transcript was never stored, the assessor has to be told before reading them.
describe("PortfolioPage", () => {
  it("warns that the ratings came from an incomplete transcript [AC-TR-01]", async () => {
    openPortfolio({ ...contract.portfolio, transcript_complete: false });

    expect(await screen.findByRole("alert")).toHaveTextContent(/transcript is incomplete/i);
    expect(screen.getByText("React / Frontend Development")).toBeInTheDocument();
  });

  it("shows no warning for a complete transcript", async () => {
    openPortfolio(contract.portfolio);

    expect(await screen.findByText("React / Frontend Development")).toBeInTheDocument();
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
  });
});
