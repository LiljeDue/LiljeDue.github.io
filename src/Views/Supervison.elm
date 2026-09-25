module Views.Supervison exposing (viewSupervison)

import Dict
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick, stopPropagationOn)
import Json.Decode as Decode
import Markdown exposing (toHtml)
import Model exposing (..)


viewSupervison : Model -> Html Msg
viewSupervison model =
    let
        cards =
            Dict.values model.projectPosts
                |> List.sortBy (.meta >> .title)
                |> List.map viewProjectCard

        modal =
            case model.openProject of
                Just href ->
                    case Dict.get href model.projectPosts of
                        Just post ->
                            viewModal model post

                        Nothing ->
                            text ""

                Nothing ->
                    text ""
    in
    div [ class "content-display" ]
        [ h1 [] [ text "Supervison" ]
        , if model.projectIntroContent /= "" then
            toHtml [ class "markdown-content" ] model.projectIntroContent

          else
            text ""
        , h1 [] [ text "Projects" ]
        , case model.projectsStatus of
            Loading ->
                div [ class "loading-spinner-wrapper" ]
                    [ div [ class "loading-spinner" ] []
                    ]

            Failure _ ->
                p [] [ text "Failed to load projects." ]

            Success ->
                div [] cards
        , modal
        ]


viewProjectCard : ProjectPost -> Html Msg
viewProjectCard post =
    div [ class "project-card", onClick (OpenProject post.href) ]
        [ h2 [] [ text post.meta.title ]
        , p [] [ text post.meta.description ]
        ]


viewModal : Model -> ProjectPost -> Html Msg
viewModal model post =
    div [ class "modal-overlay", onClick CloseProject ]
        [ div
            [ class "modal-card"
            , stopPropagationOn "click" (Decode.succeed ( NoOp, True ))
            ]
            [ button [ class "modal-close", onClick CloseProject ] [ text "×" ]
            , h2 [] [ text post.meta.title ]
            , case model.projectModalStatus of
                Loading ->
                    div [ class "loading-spinner-wrapper" ]
                        [ div [ class "loading-spinner" ] []
                        ]

                Failure _ ->
                    p [] [ text "Failed to load project content." ]

                Success ->
                    toHtml [ class "markdown-content" ] model.projectMarkdownContent
            ]
        ]
