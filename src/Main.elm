module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)


type alias Model =
    {}


init : () -> ( Model, Cmd Msg )
init _ =
    ( {}, Cmd.none )


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ h1 [] [ text "Elm with HTML and LaTeX Math" ]
        , p [] [ text "This is a simple Elm program that renders HTML content along with LaTeX math expressions." ]
        , h2 [] [ text "Example Math Expressions" ]
        , div [ class "math-block" ]
            [ -- We'll create elements with specific classes that MathJax can find
              p []
                [ text "The quadratic formula: "
                , span [ class "math" ] [ text "\\(x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\\)" ]
                ]
            , p []
                [ text "Euler's identity: "
                , span [ class "math" ] [ text "\\(e^{i\\pi} + 1 = 0\\)" ]
                ]
            , p []
                [ text "A more complex equation: "
                , div [ class "math-display" ] [ text "\\[ \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi} \\]" ]
                ]
            ]
        , p [] [ text "Above expressions will be rendered by MathJax when included in your HTML." ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }