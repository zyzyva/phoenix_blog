defmodule PhoenixBlog.AI.BlogTemplatesTest do
  use ExUnit.Case, async: true

  alias PhoenixBlog.AI.BlogTemplates

  describe "list_templates/0" do
    test "returns list of available templates" do
      templates = BlogTemplates.list_templates()
      assert is_list(templates)
      assert length(templates) > 0
    end

    test "each template has required fields" do
      templates = BlogTemplates.list_templates()

      for template <- templates do
        assert Map.has_key?(template, :name)
        assert Map.has_key?(template, :display_name)
        assert Map.has_key?(template, :description)
        assert is_atom(template.name)
        assert is_binary(template.display_name)
        assert is_binary(template.description)
      end
    end

    test "includes expected template types" do
      templates = BlogTemplates.list_templates()
      names = Enum.map(templates, & &1.name)

      assert :how_to in names
      assert :tips_list in names
      assert :scenario_guide in names
      assert :comparison in names
      assert :success_story in names
    end
  end

  describe "get_template/1" do
    test "returns template by atom name" do
      template = BlogTemplates.get_template(:how_to)
      assert template != nil
      assert template.name == :how_to
      assert template.display_name == "How-To Guide"
      assert is_binary(template.system_prompt)
      assert is_binary(template.structure_guidance)
    end

    test "returns template by string name" do
      template = BlogTemplates.get_template("how_to")
      assert template != nil
      assert template.name == :how_to
    end

    test "returns nil for unknown atom template" do
      assert BlogTemplates.get_template(:unknown_template) == nil
    end

    test "returns nil for unknown string template" do
      assert BlogTemplates.get_template("unknown_template") == nil
    end

    test "each template has system_prompt and structure_guidance" do
      for name <- BlogTemplates.template_names() do
        template = BlogTemplates.get_template(name)
        assert is_binary(template.system_prompt)
        assert String.length(template.system_prompt) > 50
        assert is_binary(template.structure_guidance)
        assert String.length(template.structure_guidance) > 50
      end
    end
  end

  describe "template_names/0" do
    test "returns list of atom names" do
      names = BlogTemplates.template_names()
      assert is_list(names)
      assert Enum.all?(names, &is_atom/1)
    end

    test "all names can be used to get templates" do
      for name <- BlogTemplates.template_names() do
        template = BlogTemplates.get_template(name)
        assert template != nil
        assert template.name == name
      end
    end
  end

  describe "template_options/0" do
    test "returns list of {display_name, string_name} tuples" do
      options = BlogTemplates.template_options()
      assert is_list(options)

      for {display_name, name_string} <- options do
        assert is_binary(display_name)
        assert is_binary(name_string)
        # Verify we can get the template with the string name
        assert BlogTemplates.get_template(name_string) != nil
      end
    end

    test "options cover all templates" do
      options = BlogTemplates.template_options()
      option_names = Enum.map(options, fn {_, name} -> String.to_atom(name) end)
      template_names = BlogTemplates.template_names()

      assert Enum.sort(option_names) == Enum.sort(template_names)
    end
  end

  describe "template content quality" do
    test "how_to template has appropriate guidance" do
      template = BlogTemplates.get_template(:how_to)
      assert template.system_prompt =~ "how-to"
      assert template.structure_guidance =~ "steps"
    end

    test "tips_list template has appropriate guidance" do
      template = BlogTemplates.get_template(:tips_list)
      assert template.system_prompt =~ "tips"
      assert template.structure_guidance =~ "numbered"
    end

    test "comparison template has appropriate guidance" do
      template = BlogTemplates.get_template(:comparison)
      assert template.system_prompt =~ "compar"
      assert template.structure_guidance =~ "Pros"
    end

    test "scenario_guide template has appropriate guidance" do
      template = BlogTemplates.get_template(:scenario_guide)
      assert template.system_prompt =~ "scenario" or template.system_prompt =~ "situation"
      assert template.structure_guidance =~ "Example"
    end

    test "success_story template has appropriate guidance" do
      template = BlogTemplates.get_template(:success_story)
      assert template.system_prompt =~ "story"
      assert template.structure_guidance =~ "outcome"
    end
  end
end
