module Main exposing (main)

import Browser
import Html exposing (..)

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }

type alias Model =
    { content : String
    }

-- Initialize with appropriate base URL
init : () -> (Model, Cmd Msg)
init _ =
    ( { content = "Loading..."
      }
    , Cmd.none
    )

type Msg = Msg ()

update : Msg -> Model -> (Model, Cmd Msg)
update _ model = (model, Cmd.none)

view : Model -> Html Msg
view model = text model.content