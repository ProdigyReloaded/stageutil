defmodule StageUtil.MixProject do
  use Mix.Project

  def project do
    [
      app: :stageutil,
      escript: [main_module: StageUtil.CLI],
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:objectutil, git: "git@github.com:ProdigyReloaded/objectutil.git"},
      {:exprintf, "~> 0.2.0"},
    ]
  end
end
