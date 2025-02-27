defmodule ZenithBackendWeb.ShaderController do
  use ZenithBackendWeb, :controller
  require Logger

  def create(conn, %{"description" => description}) do
    case ZenithBackend.Services.ShaderService.generate_shader(description) do
      {:ok, shader_code} ->
        json(conn, %{shader: shader_code})

      {:error, reason} ->
        Logger.error("Shader generation failed: #{reason}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to generate shader: #{reason}"})
    end
  end
  def fix(conn, %{"code" => code, "error" => error}) do
    case ZenithBackend.Services.ShaderService.fix_shader(code, error) do
      {:ok, shader_code} ->
        json(conn, %{shader: shader_code})

      {:error, reason} ->
        Logger.error("Shader fix failed: #{reason}")
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to fix shader: #{reason}"})
    end
  end

end
