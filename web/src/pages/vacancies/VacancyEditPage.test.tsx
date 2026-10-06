import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import VacancyEditPage from "./VacancyEditPage";
import { vacanciesApi } from "@/services/vacancies";

vi.mock("@/services/vacancies", () => ({
  vacanciesApi: { get: vi.fn(), update: vi.fn() },
}));
vi.mock("@/components/assessment/SkillPicker", () => ({ default: () => null }));

const vacancy = {
  id: 3,
  role_title: "Senior Frontend Engineer",
  culture_dimensions: "",
  competency_expectations: "",
  skills: [
    { id: 11, skill_id: "sk-eng-001", skill_label: "React / Frontend Development", expected_level: 3 },
    { id: 12, skill_id: null, skill_label: "Communication", expected_level: 3 },
  ],
};

// Pins the web half of the "remove a skill" seam. The API half
// (api/spec/requests/write_honesty_spec.rb) removes whatever this payload omits,
// which only works if kept skills are sent with their ids.
describe("VacancyEditPage", () => {
  it("sends kept skills by id and leaves the removed skill out [AC-VAC-01]", async () => {
    vi.mocked(vacanciesApi.get).mockResolvedValue({ data: { vacancy } } as never);
    vi.mocked(vacanciesApi.update).mockResolvedValue({ data: { vacancy } } as never);

    render(
      <MemoryRouter initialEntries={["/vacancies/3/edit"]}>
        <Routes>
          <Route path="/vacancies/:id/edit" element={<VacancyEditPage />} />
          <Route path="/vacancies" element={<div>list</div>} />
        </Routes>
      </MemoryRouter>
    );

    const card = (await screen.findByText("Communication")).closest("div.border") as HTMLElement;
    await userEvent.click(within(card).getAllByRole("button")[0]);
    await userEvent.click(screen.getByRole("button", { name: /save changes/i }));

    await waitFor(() => expect(vacanciesApi.update).toHaveBeenCalled());
    const payload = vi.mocked(vacanciesApi.update).mock.calls[0][1];
    expect(payload.vacancy_skills_attributes).toHaveLength(1);
    expect(payload.vacancy_skills_attributes[0]).toMatchObject({
      id: 11,
      skill_label: "React / Frontend Development",
    });
  });
});
