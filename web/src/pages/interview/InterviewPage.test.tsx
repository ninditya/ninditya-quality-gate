import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import InterviewPage from "./InterviewPage";
import { sessionsApi } from "@/services/sessions";

vi.mock("@/services/sessions", () => ({
  sessionsApi: { getCandidateInfo: vi.fn(), audioComplete: vi.fn() },
}));
vi.mock("@/components/HardwareCheck", () => ({ default: () => <div>hardware check</div> }));

function openInvite(token = "tok-abc123") {
  render(
    <MemoryRouter initialEntries={[`/interview/${token}`]}>
      <Routes>
        <Route path="/interview/:token" element={<InterviewPage />} />
      </Routes>
    </MemoryRouter>
  );
}

// What the candidate is told must match what happened to their interview.
describe("InterviewPage", () => {
  it("does not tell a candidate with a bad link that the interview is complete [AC-INT-01]", async () => {
    vi.mocked(sessionsApi.getCandidateInfo).mockRejectedValue({ response: { status: 404 } });

    openInvite();

    expect(await screen.findByRole("alert")).toHaveTextContent(/link is not valid/i);
    expect(screen.queryByText("Interview Complete")).not.toBeInTheDocument();
  });

  it("does not report completion when the interview could not be loaded [AC-INT-01]", async () => {
    vi.mocked(sessionsApi.getCandidateInfo).mockRejectedValue(new Error("Network Error"));

    openInvite();

    expect(await screen.findByRole("alert")).toHaveTextContent(/could not load/i);
    expect(screen.queryByText("Interview Complete")).not.toBeInTheDocument();
  });

  it("shows completion for an interview that really has ended", async () => {
    vi.mocked(sessionsApi.getCandidateInfo).mockResolvedValue({
      data: { session_id: 1, role_title: "Senior Frontend Engineer", time_limit_min: 45, session_status: "ended" },
    } as never);

    openInvite();

    await waitFor(() => expect(screen.getByText("Interview Complete")).toBeInTheDocument());
  });
});
