import type { AxiosAdapter, AxiosResponse } from "axios";
import api from "./api";

function respondWith(status: number): AxiosAdapter {
  return async (config) => {
    const response = { status, statusText: "", headers: {}, config, data: {} } as AxiosResponse;
    if (status >= 400) throw Object.assign(new Error("fail"), { response, config, isAxiosError: true });
    return response;
  };
}

describe("api 401/403 handling", () => {
  let assigned: string | null;

  beforeEach(() => {
    assigned = null;
    localStorage.setItem("auth_token", "jwt");
    Object.defineProperty(window, "location", {
      configurable: true,
      value: {
        pathname: "/assessments",
        get href() {
          return "http://localhost/assessments";
        },
        set href(v: string) {
          assigned = v;
        },
      },
    });
  });

  it("signs the assessor out when a session token is rejected", async () => {
    await expect(api.get("/assessments", { adapter: respondWith(401) })).rejects.toBeTruthy();

    expect(localStorage.getItem("auth_token")).toBeNull();
    expect(assigned).toBe("/login");
  });

  it("lets the login form show its own error on a wrong password [AC-AUTH-01]", async () => {
    await expect(api.post("/auth/login", {}, { adapter: respondWith(401) })).rejects.toBeTruthy();

    // Reloading /login here wiped the "Invalid email or password" message.
    expect(assigned).toBeNull();
  });
});
