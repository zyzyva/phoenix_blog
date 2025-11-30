defmodule PhoenixBlog.Keywords do
  @moduledoc """
  Context module for managing keyword research data.

  Provides functions for importing, querying, and analyzing keywords
  from Google Keyword Planner exports.
  """

  import Ecto.Query
  alias PhoenixBlog.Keywords.Keyword
  alias PhoenixBlog.Repo

  @doc """
  Returns the list of all keywords.
  """
  def list_keywords do
    Keyword
    |> order_by([k], desc: k.monthly_searches)
    |> Repo.all()
  end

  @doc """
  Returns keywords filtered by category.
  """
  def list_keywords_by_category(category) do
    Keyword
    |> where([k], k.category == ^category)
    |> order_by([k], desc: k.monthly_searches)
    |> Repo.all()
  end

  @doc """
  Returns keywords filtered by intent.
  """
  def list_keywords_by_intent(intent) do
    Keyword
    |> where([k], k.intent == ^intent)
    |> order_by([k], desc: k.monthly_searches)
    |> Repo.all()
  end

  @doc """
  Returns keywords filtered by audience.
  """
  def list_keywords_by_audience(audience) do
    Keyword
    |> where([k], k.audience == ^audience)
    |> order_by([k], desc: k.blog_score, desc: k.monthly_searches)
    |> Repo.all()
  end

  @doc """
  Returns top keywords by monthly search volume.
  """
  def top_keywords(limit \\ 50) do
    Keyword
    |> where([k], k.monthly_searches > 0)
    |> order_by([k], desc: k.monthly_searches)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns question-based keywords (good for FAQ content).
  """
  def question_keywords do
    Keyword
    |> where([k], k.is_question == true)
    |> order_by([k], desc: k.monthly_searches)
    |> Repo.all()
  end

  @doc """
  Returns keywords suitable for blog topics, sorted by blog_score.
  """
  def blog_topic_keywords(limit \\ 20) do
    Keyword
    |> where([k], k.blog_score > 0)
    |> where([k], k.is_branded == false)
    |> where([k], k.monthly_searches >= 100)
    |> order_by([k], desc: k.blog_score, desc: k.monthly_searches)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns blog topic keywords grouped by target audience.
  """
  def blog_topics_by_audience(limit_per_audience \\ 5) do
    audiences = Keyword.audiences()

    Enum.reduce(audiences, %{}, fn audience, acc ->
      keywords =
        Keyword
        |> where([k], k.audience == ^audience)
        |> where([k], k.blog_score > 0)
        |> where([k], k.is_branded == false)
        |> where([k], k.monthly_searches >= 100)
        |> order_by([k], desc: k.blog_score, desc: k.monthly_searches)
        |> limit(^limit_per_audience)
        |> Repo.all()

      if keywords == [] do
        acc
      else
        Map.put(acc, audience, keywords)
      end
    end)
  end

  @doc """
  Returns keyword statistics grouped by audience.
  """
  def stats_by_audience do
    Keyword
    |> where([k], not is_nil(k.audience))
    |> group_by([k], k.audience)
    |> select([k], %{
      audience: k.audience,
      count: count(k.id),
      total_searches: sum(k.monthly_searches),
      avg_blog_score: avg(k.blog_score)
    })
    |> order_by([k], desc: sum(k.monthly_searches))
    |> Repo.all()
  end

  @doc """
  Recalculates blog_score and audience for all existing keywords.
  """
  def recalculate_all_scores do
    Keyword
    |> Repo.all()
    |> Enum.each(&recalculate_single_score/1)
  end

  defp recalculate_single_score(keyword) do
    kw_text = keyword.keyword
    kw_lower = String.downcase(kw_text)

    audience = detect_audience(kw_lower)
    blog_score = calculate_blog_score(keyword, kw_text)

    keyword
    |> Ecto.Changeset.change(%{audience: audience, blog_score: blog_score})
    |> Repo.update()
  end

  defp detect_audience(kw_lower) do
    cond do
      String.contains?(kw_lower, ["network", "conference", "event", "meetup", "connection"]) ->
        "networking_focused"

      String.contains?(kw_lower, ["make", "create", "design", "template", "diy", "homemade"]) ->
        "diy_creators"

      String.contains?(kw_lower, ["business", "company", "professional", "corporate", "office"]) ->
        "small_business"

      String.contains?(kw_lower, [
        "startup",
        "entrepreneur",
        "freelance",
        "side hustle",
        "personal brand"
      ]) ->
        "entrepreneurs"

      String.contains?(kw_lower, ["card holder", "organizer", "wallet", "case"]) ->
        "professionals"

      true ->
        "general"
    end
  end

  defp calculate_blog_score(keyword, kw_text) do
    monthly_searches = keyword.monthly_searches || 0
    competition_index = keyword.competition_index || 50
    intent = keyword.intent
    is_question = keyword.is_question || false
    is_branded = keyword.is_branded || false

    volume_score =
      cond do
        monthly_searches >= 10_000 -> 30
        monthly_searches >= 5000 -> 25
        monthly_searches >= 1000 -> 20
        monthly_searches >= 500 -> 15
        monthly_searches >= 100 -> 10
        true -> 5
      end

    competition_score =
      cond do
        competition_index <= 30 -> 25
        competition_index <= 50 -> 20
        competition_index <= 70 -> 15
        competition_index <= 85 -> 10
        true -> 5
      end

    intent_score =
      case intent do
        "informational" -> 20
        "commercial" -> 15
        "transactional" -> 5
        "navigational" -> 0
        _ -> 10
      end

    question_bonus = if is_question, do: 15, else: 0
    branded_penalty = if is_branded, do: -30, else: 0
    low_value_penalty = if low_value_keyword?(kw_text), do: -40, else: 0

    score =
      volume_score + competition_score + intent_score + question_bonus + branded_penalty +
        low_value_penalty

    max(score, 0)
  end

  defp low_value_keyword?(keyword) do
    kw_lower = String.downcase(keyword)

    product_only_patterns = [
      ~r/^(business )?card holder[s]?$/,
      ~r/^(business )?card case[s]?$/,
      ~r/^(business )?card wallet[s]?$/,
      ~r/holder.*business card/,
      ~r/card holder.*business/,
      ~r/^card business holder$/,
      ~r/^holder business card$/,
      ~r/^card holder company$/
    ]

    Enum.any?(product_only_patterns, &Regex.match?(&1, kw_lower))
  end

  @doc """
  Gets a single keyword by ID.
  """
  def get_keyword(id), do: Repo.get(Keyword, id)

  @doc """
  Gets a single keyword by the keyword text.
  """
  def get_keyword_by_text(keyword_text) do
    Repo.get_by(Keyword, keyword: keyword_text)
  end

  @doc """
  Creates a keyword.
  """
  def create_keyword(attrs \\ %{}) do
    %Keyword{}
    |> Keyword.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a keyword.
  """
  def update_keyword(%Keyword{} = keyword, attrs) do
    keyword
    |> Keyword.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a keyword.
  """
  def delete_keyword(%Keyword{} = keyword) do
    Repo.delete(keyword)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking keyword changes.
  """
  def change_keyword(%Keyword{} = keyword, attrs \\ %{}) do
    Keyword.changeset(keyword, attrs)
  end

  @doc """
  Returns keyword statistics grouped by category.
  """
  def stats_by_category do
    Keyword
    |> group_by([k], k.category)
    |> select([k], %{
      category: k.category,
      count: count(k.id),
      total_searches: sum(k.monthly_searches)
    })
    |> order_by([k], desc: sum(k.monthly_searches))
    |> Repo.all()
  end

  @doc """
  Returns keyword statistics grouped by intent.
  """
  def stats_by_intent do
    Keyword
    |> group_by([k], k.intent)
    |> select([k], %{
      intent: k.intent,
      count: count(k.id),
      total_searches: sum(k.monthly_searches)
    })
    |> order_by([k], desc: sum(k.monthly_searches))
    |> Repo.all()
  end

  @doc """
  Returns the total count of keywords.
  """
  def count_keywords do
    Repo.aggregate(Keyword, :count)
  end

  @doc """
  Returns the total monthly search volume across all keywords.
  """
  def total_search_volume do
    Repo.aggregate(Keyword, :sum, :monthly_searches) || 0
  end

  @doc """
  Searches keywords by text pattern.
  """
  def search_keywords(query_text) do
    pattern = "%#{query_text}%"

    Keyword
    |> where([k], ilike(k.keyword, ^pattern))
    |> order_by([k], desc: k.monthly_searches)
    |> Repo.all()
  end

  @doc """
  Lists keywords with flexible filtering and sorting options.

  ## Options

  - `:search` - Text pattern to search in keyword field
  - `:category` - Filter by category
  - `:intent` - Filter by intent
  - `:audience` - Filter by audience
  - `:sort_by` - Field to sort by (default: :monthly_searches)
  - `:sort_dir` - Sort direction, :asc or :desc (default: :desc)
  - `:limit` - Maximum number of results (default: 50)
  - `:offset` - Number of results to skip (default: 0)
  """
  def list_keywords_filtered(opts \\ []) do
    search = Elixir.Keyword.get(opts, :search)
    category = Elixir.Keyword.get(opts, :category)
    intent = Elixir.Keyword.get(opts, :intent)
    audience = Elixir.Keyword.get(opts, :audience)
    sort_by = Elixir.Keyword.get(opts, :sort_by, :monthly_searches)
    sort_dir = Elixir.Keyword.get(opts, :sort_dir, :desc)
    result_limit = Elixir.Keyword.get(opts, :limit, 50)
    result_offset = Elixir.Keyword.get(opts, :offset, 0)

    Keyword
    |> apply_search_filter(search)
    |> apply_category_filter(category)
    |> apply_intent_filter(intent)
    |> apply_audience_filter(audience)
    |> apply_sort(sort_by, sort_dir)
    |> limit(^result_limit)
    |> offset(^result_offset)
    |> Repo.all()
  end

  defp apply_search_filter(query, nil), do: query
  defp apply_search_filter(query, ""), do: query

  defp apply_search_filter(query, search) do
    pattern = "%#{search}%"
    where(query, [k], ilike(k.keyword, ^pattern))
  end

  defp apply_category_filter(query, nil), do: query
  defp apply_category_filter(query, category), do: where(query, [k], k.category == ^category)

  defp apply_intent_filter(query, nil), do: query
  defp apply_intent_filter(query, intent), do: where(query, [k], k.intent == ^intent)

  defp apply_audience_filter(query, nil), do: query
  defp apply_audience_filter(query, audience), do: where(query, [k], k.audience == ^audience)

  defp apply_sort(query, :keyword, :asc), do: order_by(query, [k], asc: k.keyword)
  defp apply_sort(query, :keyword, :desc), do: order_by(query, [k], desc: k.keyword)

  defp apply_sort(query, :monthly_searches, :asc),
    do: order_by(query, [k], asc: k.monthly_searches)

  defp apply_sort(query, :monthly_searches, :desc),
    do: order_by(query, [k], desc: k.monthly_searches)

  defp apply_sort(query, :blog_score, :asc), do: order_by(query, [k], asc: k.blog_score)
  defp apply_sort(query, :blog_score, :desc), do: order_by(query, [k], desc: k.blog_score)
  defp apply_sort(query, :competition, :asc), do: order_by(query, [k], asc: k.competition)
  defp apply_sort(query, :competition, :desc), do: order_by(query, [k], desc: k.competition)
  defp apply_sort(query, :audience, :asc), do: order_by(query, [k], asc: k.audience)
  defp apply_sort(query, :audience, :desc), do: order_by(query, [k], desc: k.audience)
  defp apply_sort(query, :intent, :asc), do: order_by(query, [k], asc: k.intent)
  defp apply_sort(query, :intent, :desc), do: order_by(query, [k], desc: k.intent)
  defp apply_sort(query, _, _), do: order_by(query, [k], desc: k.monthly_searches)

  @doc """
  Deletes all keywords from the database.
  """
  def delete_all_keywords do
    Repo.delete_all(Keyword)
  end
end
