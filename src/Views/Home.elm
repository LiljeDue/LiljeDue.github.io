module Views.Home exposing (viewHome)

import Html exposing (..)
import Html.Attributes exposing (alt, class, href, src, target)
import Model exposing (..)


pltc : Html Msg
pltc =
    a [ href "https://di.ku.dk/english/research/pltc/", target "_blank" ]
        [ text "PLTC" ]


diku : Html Msg
diku =
    a [ href "https://di.ku.dk/", target "_blank" ] [ text "DIKU" ]


troels : Html Msg
troels =
    a [ href "https://hjemmesider.diku.dk/~athas/", target "_blank" ]
        [ text "Troels Henriksen" ]


viewHome : Model -> Html Msg
viewHome _ =
    div [ class "content-display" ]
        [ h1 [] [ text "Due's Website" ]
        , p []
            [ text "I am William Henrich Due, and I am a PhD student in the "
            , pltc
            , text " section at "
            , diku
            , text " here my advisor is "
            , troels
            , text ". "
            , text "My research interests are in data-parallel programming "
            , text " and high-performance computing."
            ]
        , h2 [] [ text "Connect" ]
        , div [ class "contact-icons" ]
            [ a [ href "mailto:widu@di.ku.dk", class "contact-link" ]
                [ img [ src "content/icons/email.svg", alt "Email", class "contact-icon" ] []
                , span [] []
                ]
            , a [ href "https://github.com/williamdue", target "_blank", class "contact-link" ]
                [ img [ src "content/icons/github.svg", alt "GitHub", class "contact-icon" ] []
                , span [] []
                ]
            , a [ href "https://www.linkedin.com/in/william-henrich-due-177937152/", target "_blank", class "contact-link" ]
                [ img [ src "content/icons/linkedin.svg", alt "LinkedIn", class "contact-icon" ] []
                , span [] []
                ]
            ]
        ]
