defmodule PhoenixBlog.KeywordsTest do
  use PhoenixBlog.DataCase, async: true

  alias PhoenixBlog.Keywords

  describe "keywords" do
    @valid_attrs %{
      keyword: "how to network effectively",
      monthly_searches: 1000,
      competition_index: 45
    }

    test "create_keyword/1 creates a keyword" do
      assert {:ok, keyword} = Keywords.create_keyword(@valid_attrs)
      assert keyword.keyword == "how to network effectively"
      assert keyword.monthly_searches == 1000
    end

    test "create_keyword/1 auto-categorizes the keyword" do
      assert {:ok, keyword} = Keywords.create_keyword(@valid_attrs)
      # "how to network effectively" matches networking category (before question check)
      assert keyword.category == "networking"
      assert keyword.intent == "informational"
      # is_question is based on question?() function which checks for "how to"
      # but the database field is set based on maybe_set_is_question
      # The keyword contains "how to" so it should be detected
      assert keyword.is_branded == false
    end

    test "create_keyword/1 detects branded keywords" do
      # Use a branded keyword without other category triggers
      # "vistaprint review" avoids print/printing category
      attrs = %{keyword: "is vistaprint good", monthly_searches: 5000}
      assert {:ok, keyword} = Keywords.create_keyword(attrs)
      assert keyword.is_branded == true
      assert keyword.intent == "navigational"
    end

    test "create_keyword/1 calculates blog_score" do
      assert {:ok, keyword} = Keywords.create_keyword(@valid_attrs)
      assert keyword.blog_score > 0
    end

    test "create_keyword/1 enforces unique keywords" do
      assert {:ok, _} = Keywords.create_keyword(@valid_attrs)
      assert {:error, changeset} = Keywords.create_keyword(@valid_attrs)
      assert %{keyword: ["has already been taken"]} = errors_on(changeset)
    end

    test "get_keyword/1 returns the keyword" do
      {:ok, keyword} = Keywords.create_keyword(@valid_attrs)
      assert Keywords.get_keyword(keyword.id).id == keyword.id
    end

    test "get_keyword_by_text/1 returns the keyword" do
      {:ok, keyword} = Keywords.create_keyword(@valid_attrs)
      assert Keywords.get_keyword_by_text("how to network effectively").id == keyword.id
    end

    test "update_keyword/2 updates the keyword" do
      {:ok, keyword} = Keywords.create_keyword(@valid_attrs)
      assert {:ok, updated} = Keywords.update_keyword(keyword, %{notes: "Good topic"})
      assert updated.notes == "Good topic"
    end

    test "delete_keyword/1 removes the keyword" do
      {:ok, keyword} = Keywords.create_keyword(@valid_attrs)
      assert {:ok, _} = Keywords.delete_keyword(keyword)
      assert Keywords.get_keyword(keyword.id) == nil
    end

    test "change_keyword/2 returns a changeset" do
      {:ok, keyword} = Keywords.create_keyword(@valid_attrs)
      changeset = Keywords.change_keyword(keyword, %{notes: "Test"})
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "keyword listing" do
    setup do
      {:ok, networking} =
        Keywords.create_keyword(%{
          keyword: "networking tips",
          monthly_searches: 2000,
          competition_index: 40
        })

      {:ok, scanner} =
        Keywords.create_keyword(%{
          keyword: "business card scanner app",
          monthly_searches: 5000,
          competition_index: 60
        })

      {:ok, branded} =
        Keywords.create_keyword(%{
          keyword: "vistaprint cards",
          monthly_searches: 10_000,
          competition_index: 30
        })

      {:ok, question} =
        Keywords.create_keyword(%{
          keyword: "how to design a business card",
          monthly_searches: 3000,
          competition_index: 50
        })

      %{networking: networking, scanner: scanner, branded: branded, question: question}
    end

    test "list_keywords/0 returns all keywords ordered by searches" do
      keywords = Keywords.list_keywords()
      assert length(keywords) == 4
      # Should be ordered by monthly_searches desc
      assert hd(keywords).monthly_searches == 10_000
    end

    test "list_keywords_by_category/1 filters by category" do
      scanner_keywords = Keywords.list_keywords_by_category("scanner")
      assert length(scanner_keywords) == 1
      assert hd(scanner_keywords).keyword =~ "scanner"
    end

    test "list_keywords_by_intent/1 filters by intent" do
      informational = Keywords.list_keywords_by_intent("informational")
      assert length(informational) >= 2
    end

    test "top_keywords/1 returns top N keywords" do
      top = Keywords.top_keywords(2)
      assert length(top) == 2
    end

    test "question_keywords/0 returns question-based keywords" do
      questions = Keywords.question_keywords()
      assert Enum.all?(questions, & &1.is_question)
    end

    test "blog_topic_keywords/1 returns good blog candidates" do
      topics = Keywords.blog_topic_keywords(10)
      # Should exclude branded keywords
      assert Enum.all?(topics, &(!&1.is_branded))
    end

    test "search_keywords/1 searches by text pattern" do
      results = Keywords.search_keywords("card")
      assert length(results) >= 2
    end

    test "count_keywords/0 returns total count" do
      assert Keywords.count_keywords() == 4
    end

    test "total_search_volume/0 returns sum of searches" do
      assert Keywords.total_search_volume() == 20_000
    end

    test "delete_all_keywords/0 removes all keywords" do
      assert Keywords.count_keywords() == 4
      Keywords.delete_all_keywords()
      assert Keywords.count_keywords() == 0
    end
  end

  describe "keyword statistics" do
    setup do
      {:ok, _} =
        Keywords.create_keyword(%{
          keyword: "networking tips",
          monthly_searches: 2000,
          competition_index: 40
        })

      {:ok, _} =
        Keywords.create_keyword(%{
          keyword: "business card scanner app",
          monthly_searches: 5000,
          competition_index: 60
        })

      :ok
    end

    test "stats_by_category/0 returns category stats" do
      stats = Keywords.stats_by_category()
      assert is_list(stats)
      assert Enum.all?(stats, fn s -> Map.has_key?(s, :category) end)
    end

    test "stats_by_intent/0 returns intent stats" do
      stats = Keywords.stats_by_intent()
      assert is_list(stats)
      assert Enum.all?(stats, fn s -> Map.has_key?(s, :intent) end)
    end
  end

  describe "filtered listing" do
    setup do
      {:ok, _} =
        Keywords.create_keyword(%{
          keyword: "networking tips",
          monthly_searches: 2000,
          competition_index: 40
        })

      {:ok, _} =
        Keywords.create_keyword(%{
          keyword: "business card scanner app",
          monthly_searches: 5000,
          competition_index: 60
        })

      :ok
    end

    test "list_keywords_filtered/1 filters by search term" do
      results = Keywords.list_keywords_filtered(search: "network")
      assert length(results) == 1
      assert hd(results).keyword =~ "network"
    end

    test "list_keywords_filtered/1 filters by category" do
      results = Keywords.list_keywords_filtered(category: "scanner")
      assert length(results) == 1
    end

    test "list_keywords_filtered/1 sorts by field" do
      results = Keywords.list_keywords_filtered(sort_by: :monthly_searches, sort_dir: :asc)
      assert hd(results).monthly_searches == 2000
    end

    test "list_keywords_filtered/1 limits results" do
      results = Keywords.list_keywords_filtered(limit: 1)
      assert length(results) == 1
    end
  end

  describe "keyword schema auto-categorization" do
    test "detects scanner category" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "business card scanner"})
      assert kw.category == "scanner"
    end

    test "detects digital category" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "digital business card"})
      assert kw.category == "digital"
    end

    test "detects design category" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "business card template"})
      assert kw.category == "design"
    end

    test "detects networking category" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "networking event tips"})
      assert kw.category == "networking"
    end

    test "detects comparison category" do
      # Use "vs" which triggers comparison, avoid other category triggers
      {:ok, kw} = Keywords.create_keyword(%{keyword: "apple vs samsung"})
      assert kw.category == "comparison"
    end

    test "detects transactional intent" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "buy business cards online"})
      assert kw.intent == "transactional"
    end

    test "detects informational intent" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "how to make a business card"})
      assert kw.intent == "informational"
    end

    test "detects commercial intent" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "best business card printing service"})
      assert kw.intent == "commercial"
    end
  end

  describe "audience detection" do
    test "detects networking_focused audience" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "conference networking tips"})
      assert kw.audience == "networking_focused"
    end

    test "detects diy_creators audience" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "make your own business cards"})
      assert kw.audience == "diy_creators"
    end

    test "detects small_business audience" do
      {:ok, kw} = Keywords.create_keyword(%{keyword: "professional business cards"})
      assert kw.audience == "small_business"
    end

    test "detects entrepreneurs audience" do
      # "startup" triggers entrepreneurs, avoid networking keywords
      {:ok, kw} = Keywords.create_keyword(%{keyword: "startup founder tips"})
      assert kw.audience == "entrepreneurs"
    end
  end
end
