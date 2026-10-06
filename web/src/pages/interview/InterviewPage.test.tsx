import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import InterviewPage from "./InterviewPage";
import { sessionsApi } from "@/services/sessions";
import failedInterview from "@contracts/candidate_info.json";

vi.mock("@/services/sessions", () => ({
  sessionsApi: { getCandidateInfo: vi.fn(), audioComplete: vi.fn() },
}));
vi.mock("@/components/HardwareCheck", () => ({
  default: ({ onStart }: { onStart: () => void }) => <button onClick={onStart}>start</button>,
}));
// Microphone and speaker are browser hardware; the page logic under test is not.
vi.mock("@/hooks/useAudioCapture", () => ({
  useAudioCapture: () => ({ start: async () => {}, stop: () => {}, mute: () => {}, unmute: () => {} }),
}));
vi.mock("@/hooks/useAudioPlayback", () => ({
  useAudioPlayback: () => ({
    playChunk: () => {},
    stop: () => {},
    scheduleAfterPlayback: () => {},
    waitForDrain: () => {},
    cancelDrain: () => {},
  }),
}));

// A socket that never opens: the connection is down.
class DeadSocket {
  static OPEN = 1;
  readyState = 0;
  binaryType = "";
  onopen = null;
  onmessage = null;
  onclose = null;
  onerror = null;
  send() {}
  close() {}
}

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

  it("reports a failure when the link is reopened after the interview failed [AC-INT-02]", async () => {
    vi.mocked(sessionsApi.getCandidateInfo).mockResolvedValue({ data: failedInterview } as never);

    openInvite();

    expect(await screen.findByRole("alert")).toHaveTextContent(/not completed/i);
    expect(screen.queryByText("Interview Complete")).not.toBeInTheDocument();
  });

  describe("when the candidate ends the interview while the connection is down", () => {
    beforeEach(() => {
      vi.stubGlobal("WebSocket", DeadSocket);
      vi.mocked(sessionsApi.getCandidateInfo).mockResolvedValue({
        data: { session_id: 1, role_title: "Senior Frontend Engineer", time_limit_min: 45, session_status: "active" },
      } as never);
    });
    afterEach(() => vi.unstubAllGlobals());

    async function startThenEnd() {
      openInvite("tok-abc123");
      await screen.findByText("45 minutes");
      await userEvent.click(screen.getByRole("button", { name: "start" }));
      await userEvent.click(screen.getByRole("button", { name: "End Interview" }));
      await userEvent.click(await screen.findByRole("button", { name: "End interview" }));
    }

    it("tells the server over HTTP before saying the interview is complete [AC-INT-03]", async () => {
      vi.mocked(sessionsApi.audioComplete).mockResolvedValue({ data: { ended: true } } as never);

      await startThenEnd();

      expect(await screen.findByText("Interview Complete")).toBeInTheDocument();
      expect(sessionsApi.audioComplete).toHaveBeenCalledWith("tok-abc123");
    });

    it("does not say complete when the server could not be told [AC-INT-03]", async () => {
      vi.mocked(sessionsApi.audioComplete).mockRejectedValue(new Error("Network Error"));

      await startThenEnd();

      expect(await screen.findByRole("alert")).toHaveTextContent(/not completed/i);
      expect(screen.queryByText("Interview Complete")).not.toBeInTheDocument();
    });
  });
});
