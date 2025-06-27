module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class)
import Http
import Markdown exposing (toHtml)


type alias Parameters =
    { baseContentUrl : String
    , content : List String
    }


main : Program Parameters Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    { content : String
    , baseContentUrl : String
    , status : Status
    }


type Status
    = Loading
    | Success
    | Failure Http.Error


init : Parameters -> ( Model, Cmd Msg )
init params =
    ( { content = ""
      , baseContentUrl = params.baseContentUrl
      , status = Loading
      }
    , fetchMarkdownContent params.baseContentUrl
    )


fetchMarkdownContent : String -> Cmd Msg
fetchMarkdownContent baseContentUrl =
    Http.get
        { url = baseContentUrl ++ "/content/blog/main.md"
        , expect = Http.expectString GotContent
        }


type Msg
    = GotContent (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotContent result ->
            case result of
                Ok content ->
                    ( { model | content = content, status = Success }, Cmd.none )

                Err error ->
                    ( { model | status = Failure error }, Cmd.none )


view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ h1 [] [ text "Markdown Content" ]
        , viewContent model
        ]


viewContent : Model -> Html Msg
viewContent model =
    case model.status of
        Loading ->
            p [] [ text "Loading content..." ]

        Success ->
            div [ class "content-display" ]
                [ toHtml [ class "markdown-content" ] model.content ]

        Failure _ ->
            p [ class "error" ] [ text "Failed to load content. Please try again later." ]
