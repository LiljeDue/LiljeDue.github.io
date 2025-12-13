module Views.Home exposing (viewHome)

import Html exposing (..)
import Html.Attributes exposing (class)
import Model exposing (..)
import Time exposing (Month(..))


viewHome : Model -> Html Msg
viewHome _ =
    div [ class "content-display" ]
        [ p [] [ text "Welcome to my personal website!" ]
        ]
