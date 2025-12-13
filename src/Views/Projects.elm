module Views.Projects exposing (viewProjects)

import Blog exposing (..)
import Html exposing (..)
import Html.Attributes exposing (class)
import Model exposing (..)
import Time exposing (Month(..))


viewProjects : Model -> Html Msg
viewProjects _ =
    div [ class "content-display" ]
        [ p []
            [ text """test
            project page
            """
            ]
        ]
