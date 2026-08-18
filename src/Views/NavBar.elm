port module Views.NavBar exposing (viewNavBar)

import Blog exposing (..)
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Model exposing (..)
import Time exposing (Month(..))


port renderMathJax : () -> Cmd msg


viewNavBarItem : Page -> Page -> String -> String -> Html Msg
viewNavBarItem currentPage page name href =
    let
        activeClass =
            if currentPage == page then
                "navbar-item active"

            else
                "navbar-item"
    in
    li [ class activeClass ]
        [ a [ class "navbar-link", Html.Attributes.href href, onClick (NavigateTo page) ] [ text name ] ]


viewNavBar : Page -> Html Msg
viewNavBar currentPage =
    nav [ class "navbar" ]
        [ ul [ class "navbar-items" ]
            [ viewNavBarItem currentPage Home "Home" "/"
            , viewNavBarItem currentPage Blogs "Blog" "/blog"
            , viewNavBarItem currentPage Projects "Projects" "/projects"
            ]
        ]
