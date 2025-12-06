import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "option"];

  connect() {
    this.#updateSelection();
  }

  select({ currentTarget }) {
    const modelId = currentTarget.dataset.modelId;
    this.inputTarget.value = modelId;
    this.#updateSelection();
  }

  #updateSelection() {
    const selectedModel = this.inputTarget.value;

    this.optionTargets.forEach((option) => {
      const isSelected = option.dataset.modelId === selectedModel;

      if (isSelected) {
        option.classList.add("bg-container", "text-primary", "shadow-border-xs");
        option.classList.remove("text-secondary", "hover:text-primary");
      } else {
        option.classList.remove("bg-container", "text-primary", "shadow-border-xs");
        option.classList.add("text-secondary", "hover:text-primary");
      }
    });
  }
}
