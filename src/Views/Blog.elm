module Views.Blog exposing (viewBlog, viewBlogPosts, viewPage)

import Blog exposing (..)
import Date
import Dict
import Html exposing (..)
import Html.Attributes exposing (alt, class, href, src, target)
import Html.Events exposing (onClick)
import Model exposing (..)
import Time exposing (Month(..))
import Html.Attributes exposing (src)


viewPage : Model -> Html Msg -> Html Msg
viewPage model page =
    case model.status of
        Loading ->
            div [ class "loading-display" ]
                [ div [ class "loading-spinner-wrapper" ]
                    [ div [ class "loading-spinner" ] []
                    , p [ class "loading-text" ] [ text "Loading..." ]
                    ]
                ]

        Success ->
            div [ class "content-display" ]
                [ page ]

        Failure _ ->
            div [ class "error-display" ] [ h1 [] [ text "Failed to load content. Please try again later." ] ]


{-| Blog posts are static pages built by pandoc (blog/<slug>/index.html), so
the Elm app only reaches this route when no such page exists.
-}
viewBlog : Model -> String -> Html Msg
viewBlog model _ =
    viewPage model (div [] [ text "Blog post not found." ])


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
              , a [ href "content/feed.xml", target "_blank", class "links-link atom-rss-link" ]
                  [ img [ src "content/icons/atom_rss.svg", alt "Atom/RSS", class "atom-rss-icon" ] []
                  , span [ class "atom-rss-label" ] [ text "Atom/RSS" ]
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
