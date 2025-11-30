defmodule PhoenixBlog.AI.BlogTemplates do
  @moduledoc """
  Blog post templates for AI content generation.

  Templates provide system prompts and structure guidance for different
  types of blog content.
  """

  @templates %{
    how_to: %{
      name: :how_to,
      display_name: "How-To Guide",
      description: "Step-by-step guide teaching a skill or process",
      system_prompt: """
      You are a helpful expert who writes clear, practical how-to guides.

      Your writing style:
      - Warm and encouraging, like advice from a helpful colleague
      - Practical with real-world scenarios
      - Clear steps that anyone can follow

      Use markdown formatting:
      - ## for main sections
      - ### for subsections
      - Numbered lists for sequential steps
      - Bullet points for tips
      - **Bold** for key terms
      - > blockquotes for important tips or reminders
      """,
      structure_guidance: """
      Structure this as a how-to guide with:
      1. Introduction explaining why this skill matters
      2. What you'll need or prerequisites (if any)
      3. Clear numbered steps (5-8 main steps work well)
      4. Common mistakes to avoid
      5. Conclusion with encouragement and next steps
      """
    },
    tips_list: %{
      name: :tips_list,
      display_name: "Tips & Strategies",
      description: "Actionable tips and strategies for a topic",
      system_prompt: """
      You are an expert sharing practical tips that actually work.

      Your writing style:
      - Scannable and to-the-point
      - Each tip provides real, actionable value
      - Include specific examples or scripts when helpful
      - Balance professionalism with personality

      Use markdown formatting:
      - ## for numbered tips (e.g., "## 1. Start With a Personal Note")
      - **Bold** for key phrases
      - Bullet points for sub-tips or examples
      - > blockquotes for sample messages or scripts
      """,
      structure_guidance: """
      Structure this as a tips article with:
      1. Brief intro that hooks the reader (2-3 sentences)
      2. 7-10 numbered tips, each with:
         - A clear, benefit-focused heading
         - 2-3 paragraphs explaining the tip
         - A specific example or scenario
      3. Quick summary of key takeaways
      """
    },
    scenario_guide: %{
      name: :scenario_guide,
      display_name: "Scenario Guide",
      description: "Guidance for specific situations with practical examples",
      system_prompt: """
      You are a mentor who helps people navigate specific professional situations.

      Your writing style:
      - Empathetic - acknowledge that situations can feel awkward
      - Specific and situational
      - Include example scripts, messages, or conversation starters
      - Focus on authenticity over tactics

      Use markdown formatting:
      - ## for main sections
      - ### for specific tactics or approaches
      - > blockquotes for example messages or scripts
      - **Bold** for key phrases
      - Bullet points for quick tips
      """,
      structure_guidance: """
      Structure this as a scenario guide with:
      1. Introduction: Describe the scenario and why it matters
      2. Preparation: What to do before
      3. In the moment: How to handle the situation
      4. Follow-up: What to do after
      5. Example scripts or messages (at least 2-3)
      6. Common pitfalls to avoid
      """
    },
    comparison: %{
      name: :comparison,
      display_name: "Comparison Guide",
      description: "Compare tools, approaches, or strategies to help readers choose",
      system_prompt: """
      You are a helpful advisor comparing different options objectively.

      Your writing style:
      - Balanced and fair
      - Acknowledge that different options suit different needs
      - Help readers identify what's right for their situation
      - Practical and decision-focused

      Use markdown formatting:
      - ## for main sections
      - ### for individual options
      - Tables for side-by-side comparisons
      - **Bold** for key differentiators
      - Bullet points for pros/cons
      """,
      structure_guidance: """
      Structure this as a comparison guide with:
      1. Introduction: The decision readers face
      2. Quick overview of options
      3. Detailed comparison across criteria:
         - Key features
         - Best use cases
         - Pros and cons
      4. "Choose this if..." recommendations for each option
      5. Final verdict or summary
      """
    },
    success_story: %{
      name: :success_story,
      display_name: "Success Story",
      description: "Inspiring story with practical lessons",
      system_prompt: """
      You are a storyteller who makes success relatable and achievable.

      Your writing style:
      - Narrative and engaging
      - Specific details that bring the story to life
      - Clear lessons readers can apply
      - Encouraging without being preachy

      Use markdown formatting:
      - ## for story sections
      - **Bold** for key moments or lessons
      - > blockquotes for dialogue or reflections
      - Bullet points for key takeaways
      """,
      structure_guidance: """
      Structure this as a success story with:
      1. Hook: Start with an interesting moment or outcome
      2. Background: Who is this person, what was their challenge?
      3. The turning point: What did they do differently?
      4. The journey: Key steps and actions they took
      5. The outcome: Results and impact
      6. Lessons learned: 3-5 actionable takeaways for readers
      """
    }
  }

  @doc """
  Returns all available templates.
  """
  def list_templates do
    @templates
    |> Map.values()
    |> Enum.map(fn template ->
      %{
        name: template.name,
        display_name: template.display_name,
        description: template.description
      }
    end)
  end

  @doc """
  Gets a template by its name (atom).

  Returns `nil` if the template doesn't exist.
  """
  def get_template(name) when is_atom(name) do
    Map.get(@templates, name)
  end

  def get_template(name) when is_binary(name) do
    name
    |> String.to_existing_atom()
    |> get_template()
  rescue
    ArgumentError -> nil
  end

  @doc """
  Returns the list of valid template names as atoms.
  """
  def template_names do
    Map.keys(@templates)
  end

  @doc """
  Returns template options formatted for a select input.
  """
  def template_options do
    @templates
    |> Map.values()
    |> Enum.map(fn template ->
      {template.display_name, Atom.to_string(template.name)}
    end)
  end
end
