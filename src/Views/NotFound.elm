module Views.NotFound exposing (viewNotFound)

import Html exposing (..)
import Html.Attributes exposing (class)
import Model exposing (..)


viewNotFound : Model -> Html Msg
viewNotFound _ =
    div [ class "content-display" ]
        [ h1 [] [ text "404 - Page Not Found" ]
        , p [] [ text "The page you are looking for does not exist." ]
        ]
