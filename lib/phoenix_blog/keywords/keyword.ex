defmodule PhoenixBlog.Keywords.Keyword do
  @moduledoc """
  Schema for storing keyword research data from Google Keyword Planner exports.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @categories ~w(scanner printing digital design networking comparison question brand other)
  @intents ~w(informational transactional navigational commercial)
  @audiences ~w(entrepreneurs small_business professionals networking_focused diy_creators general)

  schema "blog_keywords" do
    field :keyword, :string
    field :monthly_searches, :integer, default: 0
    field :competition, :string
    field :competition_index, :integer
    field :three_month_change, :string
    field :yoy_change, :string
    field :top_bid_low, :decimal
    field :top_bid_high, :decimal

    # Categorization
    field :category, :string
    field :intent, :string
    field :is_question, :boolean, default: false
    field :is_branded, :boolean, default: false

    # Audience and blog optimization
    field :audience, :string
    field :blog_score, :integer, default: 0

    # For content planning
    field :suggested_topics, {:array, :string}, default: []
    field :notes, :string

    timestamps()
  end

  def changeset(keyword, attrs) do
    keyword
    |> cast(attrs, [
      :keyword,
      :monthly_searches,
      :competition,
      :competition_index,
      :three_month_change,
      :yoy_change,
      :top_bid_low,
      :top_bid_high,
      :category,
      :intent,
      :is_question,
      :is_branded,
      :audience,
      :blog_score,
      :suggested_topics,
      :notes
    ])
    |> validate_required([:keyword])
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:intent, @intents)
    |> validate_inclusion(:audience, @audiences ++ [nil])
    |> unique_constraint(:keyword)
    |> auto_categorize()
  end

  defp auto_categorize(changeset) do
    case get_change(changeset, :keyword) do
      nil ->
        changeset

      kw ->
        changeset
        |> maybe_set_category(kw)
        |> maybe_set_intent(kw)
        |> maybe_set_is_question(kw)
        |> maybe_set_is_branded(kw)
        |> maybe_set_audience(kw)
        |> calculate_blog_score()
    end
  end

  defp maybe_set_category(changeset, kw) do
    if get_field(changeset, :category) do
      changeset
    else
      put_change(changeset, :category, detect_category(kw))
    end
  end

  defp maybe_set_intent(changeset, kw) do
    if get_field(changeset, :intent) do
      changeset
    else
      put_change(changeset, :intent, detect_intent(kw))
    end
  end

  defp maybe_set_is_question(changeset, kw) do
    if get_field(changeset, :is_question) != nil do
      changeset
    else
      put_change(changeset, :is_question, is_question?(kw))
    end
  end

  defp maybe_set_is_branded(changeset, kw) do
    if get_field(changeset, :is_branded) != nil do
      changeset
    else
      put_change(changeset, :is_branded, is_branded?(kw))
    end
  end

  defp detect_category(kw) do
    kw_lower = String.downcase(kw)

    cond do
      String.contains?(kw_lower, ["scanner", "scan", "reader", "ocr"]) -> "scanner"
      String.contains?(kw_lower, ["print", "printing", "order", "buy"]) -> "printing"
      String.contains?(kw_lower, ["digital", "qr", "nfc", "virtual", "electronic"]) -> "digital"
      String.contains?(kw_lower, ["design", "template", "make", "create", "maker"]) -> "design"
      String.contains?(kw_lower, ["network", "event", "conference", "meetup"]) -> "networking"
      String.contains?(kw_lower, ["vs", "versus", "compare", "best", "top"]) -> "comparison"
      is_question?(kw_lower) -> "question"
      is_branded?(kw_lower) -> "brand"
      true -> "other"
    end
  end

  defp detect_intent(kw) do
    kw_lower = String.downcase(kw)

    cond do
      String.contains?(kw_lower, ["buy", "order", "price", "cost", "cheap", "free", "near me"]) ->
        "transactional"

      String.contains?(kw_lower, ["how to", "what is", "why", "guide", "tips", "ideas"]) ->
        "informational"

      is_branded?(kw_lower) ->
        "navigational"

      String.contains?(kw_lower, ["best", "top", "review", "compare", "vs"]) ->
        "commercial"

      true ->
        "informational"
    end
  end

  defp is_question?(kw) do
    kw_lower = String.downcase(kw)

    String.contains?(kw_lower, [
      "how to",
      "what is",
      "what are",
      "why",
      "when",
      "where",
      "which",
      "should i",
      "do i need",
      "can i",
      "is it"
    ])
  end

  defp is_branded?(kw) do
    kw_lower = String.downcase(kw)

    String.contains?(kw_lower, [
      "vistaprint",
      "moo",
      "staples",
      "fedex",
      "ups",
      "canva",
      "zazzle",
      "avery",
      "gotprint",
      "uprinting",
      "amazon",
      "office depot",
      "shutterfly"
    ])
  end

  defp maybe_set_audience(changeset, kw) do
    if get_field(changeset, :audience) do
      changeset
    else
      put_change(changeset, :audience, detect_audience(kw))
    end
  end

  defp detect_audience(kw) do
    kw_lower = String.downcase(kw)

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

  defp calculate_blog_score(changeset) do
    monthly_searches = get_field(changeset, :monthly_searches) || 0
    competition_index = get_field(changeset, :competition_index) || 50
    intent = get_field(changeset, :intent)
    is_question = get_field(changeset, :is_question) || false
    is_branded = get_field(changeset, :is_branded) || false
    keyword = get_field(changeset, :keyword) || ""

    volume_score =
      cond do
        monthly_searches >= 10000 -> 30
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
    low_value_penalty = if is_low_value_keyword?(keyword), do: -40, else: 0

    score =
      volume_score + competition_score + intent_score + question_bonus + branded_penalty +
        low_value_penalty

    put_change(changeset, :blog_score, max(score, 0))
  end

  defp is_low_value_keyword?(keyword) do
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

  def categories, do: @categories
  def intents, do: @intents
  def audiences, do: @audiences
end
