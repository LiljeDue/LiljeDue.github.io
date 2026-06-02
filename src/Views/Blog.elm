module Views.Blog exposing (viewBlog, viewBlogPosts, viewPage)

import Blog exposing (..)
import Date
import Dict
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Markdown exposing (toHtml)
import Model exposing (..)
import Time exposing (Month(..))
import Regex

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


normalizeMarkdown : String -> String
normalizeMarkdown markdown =
    let
        fencePattern =
            Regex.fromString "```[\\s\\S]*?```|\\$\\$[\\s\\S]*?\\$\\$"
                |> Maybe.withDefault Regex.never

        normalizeParagraphs text =
          text
              |> String.split "\n\n"
              |> List.map (String.lines >> String.join " ")
              |> String.join "\n\n"

        matches =
            Regex.find fencePattern markdown

        { result, lastIndex } =
            List.foldl
                (\match acc ->
                    let
                        normalPart =
                            String.slice acc.lastIndex match.index markdown
                    in
                    { result = acc.result ++ normalizeParagraphs normalPart ++ match.match
                    , lastIndex = match.index + String.length match.match
                    }
                )
                { result = "", lastIndex = 0 }
                matches

        trailing =
            String.slice lastIndex (String.length markdown) markdown
    in
    result ++ normalizeParagraphs trailing


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
