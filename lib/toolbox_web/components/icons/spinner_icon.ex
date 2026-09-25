defmodule ToolboxWeb.Components.Icons.SpinnerIcon do
  use Phoenix.Component

  attr :class, :string, default: nil

  def spinner_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="40"
      height="40"
      viewBox="0 0 40 40"
      fill="none"
      class={["animate-[spin_2s_linear_infinite]", @class]}
    >
      <ellipse cx="36.3511" cy="20.5112" rx="3.6499" ry="3.64989" class="fill-primary-600" />
      <circle
        cx="3.64989"
        cy="3.64989"
        r="3.64989"
        transform="matrix(0.707108 0.707106 -0.707108 0.707106 31.3184 27.0723)"
        class="fill-primary-700"
      />
      <ellipse cx="19.9272" cy="3.64989" rx="3.6499" ry="3.64989" class="fill-primary-400" />
      <circle
        cx="3.64989"
        cy="3.64989"
        r="3.64989"
        transform="matrix(0.707108 0.707106 -0.707108 0.707106 31.6289 3.53516)"
        class="fill-primary-500"
      />
      <ellipse cx="3.6499" cy="20.0796" rx="3.6499" ry="3.64989" class="fill-primary-200" />
      <circle
        cx="3.64989"
        cy="3.64989"
        r="3.64989"
        transform="matrix(0.707108 0.707106 -0.707108 0.707106 8.50195 3.64453)"
        class="fill-primary-300"
      />
      <ellipse cx="19.4995" cy="36.0581" rx="3.6499" ry="3.64989" class="fill-primary-800" />
      <circle
        cx="3.64989"
        cy="3.64989"
        r="3.64989"
        transform="matrix(0.707108 0.707106 -0.707108 0.707106 8.41016 26.1504)"
        class="fill-primary-900"
      />
    </svg>
    """
  end
end
