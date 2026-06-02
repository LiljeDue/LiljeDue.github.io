module Views.Blog exposing (viewBlog, viewBlogPosts, viewPage)

import Blog exposing (..)
import Date
import Dict
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Markdown exposing (toHtml)
import Model exposing (..)
import Parser exposing (Parser, Step(..), (|.), (|=))
import Time exposing (Month(..))


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
    = Protected String
    | Paragraph String


fenceBlock : Parser Segment
fenceBlock =
    Parser.succeed (\inner -> Protected ("```" ++ inner ++ "```"))
        |. Parser.token "```"
        |= Parser.getChompedString (Parser.chompUntil "```")
        |. Parser.token "```"


mathBlock : Parser Segment
mathBlock =
    Parser.succeed (\inner -> Protected ("$$" ++ inner ++ "$$"))
        |. Parser.token "$$"
        |= Parser.getChompedString (Parser.chompUntil "$$")
        |. Parser.token "$$"


-- Parses a single paragraph: consumes chars one at a time, stopping at
-- \n\n, a protected block delimiter, or end of input.
-- Single \n within the paragraph are collapsed to spaces.
paragraphContentHelp : List String -> Parser (Step (List String) (List String))
paragraphContentHelp acc =
    Parser.oneOf
        [ Parser.end
            |> Parser.map (\_ -> Done acc)
        , Parser.backtrackable (Parser.token "\n\n")
            |> Parser.map (\_ -> Done acc)
        , Parser.backtrackable (Parser.token "```")
            |> Parser.map (\_ -> Done acc)
        , Parser.backtrackable (Parser.token "$$")
            |> Parser.map (\_ -> Done acc)
        , Parser.getChompedString (Parser.chompIf (\_ -> True))
            |> Parser.map (\c -> Loop (c :: acc))
        ]


paragraphParser : Parser Segment
paragraphParser =
    Parser.loop [] paragraphContentHelp
        |> Parser.map
            (\chars ->
                chars
                    |> List.reverse
                    |> String.concat
                    |> String.lines
                    |> String.join " "
                    |> Paragraph
            )


segmentHelp : List Segment -> Parser (Step (List Segment) (List Segment))
segmentHelp acc =
    Parser.oneOf
        [ Parser.end
            |> Parser.map (\_ -> Done (List.reverse acc))
        , Parser.backtrackable fenceBlock
            |> Parser.map (\seg -> Loop (seg :: acc))
        , Parser.backtrackable mathBlock
            |> Parser.map (\seg -> Loop (seg :: acc))
        -- consume \n\n separators without adding a segment
        , Parser.backtrackable (Parser.token "\n\n")
            |> Parser.map (\_ -> Loop acc)
        , paragraphParser
            |> Parser.map
                (\seg ->
                    case seg of
                        Paragraph "" -> Loop acc
                        _            -> Loop (seg :: acc)
                )
        ]


segmentParser : Parser (List Segment)
segmentParser =
    Parser.loop [] segmentHelp


normalizeMarkdown : String -> String
normalizeMarkdown markdown =
    Parser.run segmentParser markdown
        |> Result.withDefault [ Paragraph markdown ]
        |> List.map
            (\seg ->
                case seg of
                    Protected s ->
                        s

                    Paragraph s ->
                        s
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
                    , br [] []
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
    viewPage model (div [] blogPosts)


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
