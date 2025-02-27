defmodule ZenithBackend.Services.ShaderService do
  require Logger

  @gemini_api_base "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

  defp api_key do
    Application.fetch_env!(:zenith_backend, :gemini_api_key)
  end

  def generate_shader(description) do
    prompt = """
    You are a WebGL shader programming expert. Generate a simple 2D WebGL shader based on this description: "#{description}"

    Your response must ONLY contain shader code without any explanations, HTML, markdown or other formatting.

    Structure your response exactly as follows:
    // VERTEX SHADER
    precision mediump float;
    attribute vec2 position; // Ensure this line is present
    varying vec2 vUv;
    uniform float time;
    uniform vec2 resolution;
    // ... other declarations as needed ...

    void main() {
      vUv = position * 0.5 + 0.5;
      gl_Position = vec4(position, 0.0, 1.0);
    }

    // FRAGMENT SHADER
    precision mediump float;
    varying vec2 vUv;
    uniform float time;
    uniform vec2 resolution;
    // ... other declarations as needed ...

    void main() {
      // Implement your fragment shader based on the description
      // Use vUv for texture coordinates and time for animation
      vec3 color = vec3(0.0);

      // Add your 2D effects here
      // ...

      gl_FragColor = vec4(color, 1.0);
    }

    Technical requirements:
    1. Focus on 2D effects only (no 3D transformations)
    2. Use 'time' uniform for animations (measured in seconds)
    3. Use 'resolution' uniform for adjusting effects to the canvas size
    4. Implement creative effects like gradients, patterns, noise, distortion
    5. Keep the shaders simple and performant
    6. Make sure the shader compiles without errors
    7. Avoid complex raymarching techniques
    """

    request_api_with_prompt(prompt)
  end

  def fix_shader(code, error) do
    prompt = """
    You are a WebGL shader programming expert. Fix the following shader code that's producing an error:

    ERROR:
    #{error}

    SHADER CODE:
    #{code}

    Respond with ONLY the fixed shader code. No explanations, markdown, or additional text.
    """

    request_api_with_prompt(prompt)
  end

  defp request_api_with_prompt(prompt) do
    payload = %{contents: [%{parts: [%{text: prompt}]}]}

    with {:ok, body} <- Jason.encode(payload),
         api_url <- "#{@gemini_api_base}?key=#{api_key()}",
         {:ok, response} <- ZenithBackend.Services.ShaderService.post(api_url, body),
         {:ok, shader_code} <- extract_shader_code(response) do
      {:ok, shader_code}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_shader_code(response) do
    with candidates when is_list(candidates) <- Map.get(response, "candidates"),
         candidate when not is_nil(candidate) <- List.first(candidates),
         content <- Map.get(candidate, "content"),
         parts when is_list(parts) <- Map.get(content, "parts"),
         first_part <- Enum.at(parts, 0),
         shader_code when not is_nil(shader_code) <- Map.get(first_part, "text") do
      {:ok, shader_code}
    else
      _ -> {:error, "Failed to extract shader code"}
    end
  end

  def post(url, body) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    request = Finch.build(:post, url, headers, body)

    case Finch.request(request, ZenithBackend.Finch, receive_timeout: 50_000) do
      {:ok, %Finch.Response{status: status, body: response_body}} when status in 200..299 ->
        Jason.decode(response_body)

      {:ok, %Finch.Response{status: status, body: response_body}} ->
        error_message = extract_error_message(response_body, status)
        {:error, "API request failed: #{error_message}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp extract_error_message(response_body, status) do
    case Jason.decode(response_body) do
      {:ok, decoded} -> Map.get(decoded, "error", %{}) |> Map.get("message", "Unknown error")
      _ -> "Status: #{status}, Body: #{response_body}"
    end
  end

end
