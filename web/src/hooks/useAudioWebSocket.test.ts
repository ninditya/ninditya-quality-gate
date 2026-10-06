import { renderHook, act } from "@testing-library/react";
import { useAudioWebSocket } from "./useAudioWebSocket";
import type { InterviewState } from "@/types";

class FakeSocket {
  static instances: FakeSocket[] = [];
  static OPEN = 1;
  readyState = 0;
  binaryType = "";
  onopen: (() => void) | null = null;
  onmessage: ((e: { data: unknown }) => void) | null = null;
  onclose: (() => void) | null = null;
  onerror: (() => void) | null = null;
  constructor(public url: string) {
    FakeSocket.instances.push(this);
  }
  send() {}
  close() {
    this.onclose?.();
  }
  receive(msg: object) {
    this.onmessage?.({ data: JSON.stringify(msg) });
  }
}

function setup() {
  const states: InterviewState[] = [];
  const hook = renderHook(() =>
    useAudioWebSocket({
      sessionId: 1,
      token: "tok",
      onAudioChunk: () => {},
      onTranscript: () => {},
      onStateChange: (s) => states.push(s),
      onSpeakerChange: () => {},
    })
  );
  act(() => hook.result.current.connect());
  return { states, latest: () => FakeSocket.instances[FakeSocket.instances.length - 1] };
}

const last = <T,>(items: T[]) => items[items.length - 1];

// "complete" tells the candidate their interview was recorded. It may only
// follow a session the server actually ended.
describe("useAudioWebSocket end states", () => {
  beforeEach(() => {
    FakeSocket.instances = [];
    vi.stubGlobal("WebSocket", FakeSocket);
    vi.useFakeTimers();
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it("reports completion when the server ends the session", () => {
    const { states, latest } = setup();

    act(() => latest().receive({ type: "session_ended", reason: "all_covered" }));

    expect(last(states)).toBe("complete");
  });

  it("reports failure, not completion, when the server ends the session on an error [AC-INT-02]", () => {
    const { states, latest } = setup();

    act(() => latest().receive({ type: "session_ended", reason: "error" }));

    expect(last(states)).toBe("failed");
  });

  it("reports failure, not completion, on a non-recoverable error [AC-INT-02]", () => {
    const { states, latest } = setup();

    act(() => latest().receive({ type: "error", code: "auth_failed", recoverable: false }));

    expect(last(states)).toBe("failed");
  });

  it("reports failure, not completion, when reconnecting gives up [AC-INT-02]", () => {
    const { states, latest } = setup();

    // Every connection drops; the hook retries three times, then stops.
    for (let i = 0; i < 4; i++) {
      act(() => latest().close());
      act(() => vi.advanceTimersByTime(5000));
    }

    expect(last(states)).toBe("failed");
    expect(states).not.toContain("complete");
  });
});
