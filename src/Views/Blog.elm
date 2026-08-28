module Views.Blog exposing (viewBlog, viewBlogPosts, viewPage)

import Blog exposing (..)
import Date
import Dict
import Html exposing (..)
import Html.Attributes exposing (alt, class, href, src, target)
import Html.Events exposing (onClick)
import Markdown exposing (toHtml)
import Model exposing (..)
import Parser exposing (Parser, Step(..), (|.), (|=))
import Time exposing (Month(..))
import Html.Attributes exposing (src)


viewPage : Model -> Html Msg -> Html Msg
viewPage model page =
    case model.status of
        Loading ->
            div [ class "loading-display" ] [ h1 [] [ text "Loading blog post..." ] ]

        Success ->
            div [ class "content-display" ]
                [ page ]

        Failure _ ->
            div [ class "error-display" ] [ h1 [] [ text "Failed to load content. Please try again later." ] ]


type Segment
    = ProtectedMath String
    | ProtectedCode String
    | Paragraph String


fenceBlock : Parser Segment
fenceBlock =
    Parser.succeed (\inner -> ProtectedCode ("```" ++ inner ++ "```"))
        |. Parser.token "```"
        |= Parser.getChompedString (Parser.chompUntil "```")
        |. Parser.token "```"


mathBlock : Parser Segment
mathBlock =
    Parser.succeed (\inner -> ProtectedMath ("$$" ++ inner ++ "$$"))
        |. Parser.token "$$"
        |= Parser.getChompedString (Parser.chompUntil "$$")
        |. Parser.token "$$"


paragraph : Parser Segment
paragraph =
    Parser.getChompedString (Parser.chompUntilEndOr "\n\n")
        |> Parser.map (\s -> Paragraph (s |> String.lines |> String.join " "))


segment : Parser Segment
segment =
    Parser.oneOf
        [ Parser.backtrackable fenceBlock
        , Parser.backtrackable mathBlock
        , paragraph
        ]


segmentHelp : List Segment -> Parser (Step (List Segment) (List Segment))
segmentHelp acc =
    Parser.oneOf
        [ Parser.end |> Parser.map (\_ -> Done (List.reverse acc))
        , Parser.token "\n\n" |> Parser.map (\_ -> Loop acc)
        , segment |> Parser.map (\seg -> Loop (seg :: acc))
        ]


segmentParser : Parser (List Segment)
segmentParser =
    Parser.loop [] segmentHelp

type Math
    = Display String
    | Inline String
    | Plain String


escapeMathUnderscores : String -> String
escapeMathUnderscores s =
    Parser.run mathParser s
        |> Result.map (List.map render >> String.join "")
        |> Result.withDefault s


render : Math -> String
render m =
    case m of
        Display inner ->
            "$$" ++ String.replace "_" "\\_" inner ++ "$$"

        Inline inner ->
            "$" ++ String.replace "_" "\\_" inner ++ "$"

        Plain t ->
            t


mathParser : Parser (List Math)
mathParser =
    Parser.loop [] mathHelp


mathHelp : List Math -> Parser (Step (List Math) (List Math))
mathHelp acc =
    Parser.oneOf
        [ Parser.end |> Parser.map (\_ -> Done (List.reverse acc))
        , Parser.backtrackable displayMath |> Parser.map (\m -> Loop (m :: acc))
        , Parser.backtrackable inlineMath |> Parser.map (\m -> Loop (m :: acc))
        , plainText |> Parser.map (\t -> Loop (t :: acc))
        ]


displayMath : Parser Math
displayMath =
    Parser.succeed Display
        |. Parser.token "$$"
        |= Parser.getChompedString (Parser.chompUntil "$$")
        |. Parser.token "$$"


inlineMath : Parser Math
inlineMath =
    Parser.succeed Inline
        |. Parser.token "$"
        |= Parser.getChompedString (Parser.chompUntil "$")
        |. Parser.token "$"


plainText : Parser Math
plainText =
    Parser.getChompedString
        (Parser.chompIf (\_ -> True)
            |. Parser.chompWhile (\c -> c /= '$')
        )
        |> Parser.map Plain


normalizeMarkdown : String -> String
normalizeMarkdown markdown =
    Parser.run segmentParser markdown
        |> Result.withDefault [ Paragraph markdown ]
        |> List.map
            (\seg ->
                case seg of
                    ProtectedCode s ->
                        s

                    ProtectedMath s ->
                        String.replace "\\\\" "\\\\\\\\" s
                        |> String.replace "_" "\\_"

                    Paragraph s ->
                        escapeMathUnderscores s
            )
        |> String.join "\n\n"


viewBlog : Model -> String -> Html Msg
viewBlog model href =
    case Dict.get href model.blogPosts of
        Nothing ->
            viewPage model (div [] [ text "Blog post not found." ])

        Just post ->
            viewPage model
                (div []
                    [ h1 [] [ text post.meta.title ]
                    , p [] [ text (Date.format "d MMMM y" post.meta.date) ]
                    , br [ class "content-sep" ] []
                    , toHtml [ class "markdown-content" ] (normalizeMarkdown model.markdownContent)
                    ]
                )


viewBlogPosts : Model -> Html Msg
viewBlogPosts model =
    let
        blogPosts =
            Dict.values model.blogPosts
                |> List.sortWith (\p0 p1 -> Date.compare p1.meta.date p0.meta.date)
                |> List.map viewBlogCard
    in
    viewPage model
        (div []
            [ h1 [ class "blog-heading" ]
              [ text "Blog"
              , a [ href "content/feed.xml", target "_blank", class "links-link atom-link" ]
                  [ img [ src "content/icons/atom.svg", alt "Atom", class "atom-icon" ] []
                  , span [ class "atom-label" ] [ text "Atom" ]
                  ]
              ]
            , div [] blogPosts
            ]
        )


viewBlogCard : BlogPost -> Html Msg
viewBlogCard post =
    div [ class "blog-card", Html.Attributes.href post.href, onClick (NavigateTo (Blog post.href)) ]
        [ div []
            [ h1 [] [ text post.meta.title ]
            , p [] [ text (Date.format "d MMMM y" post.meta.date) ]
            , br [] []
            , p [] [ text post.meta.description ]
            ]
        ]
