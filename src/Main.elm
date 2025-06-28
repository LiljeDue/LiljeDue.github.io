port module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Markdown exposing (toHtml)
import StringTrie exposing (Trie)


port renderMathJax : () -> Cmd msg


type Page
    = Home
    | Blog
    | Projects


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
    { content : Trie ()
    , markdownContent : String
    , baseContentUrl : String
    , status : Status
    , currentPage : Page
    }


type Status
    = Loading
    | Success
    | Failure Http.Error


init : Parameters -> ( Model, Cmd Msg )
init params =
    ( { content = StringTrie.fromList (List.map (\s -> ( s, () )) params.content)
      , markdownContent = ""
      , baseContentUrl = params.baseContentUrl
      , status = Loading
      , currentPage = Home
      }
    , Cmd.none
    )


fetchMarkdownContent : String -> Cmd Msg
fetchMarkdownContent baseContentUrl =
    Http.get
        { url = baseContentUrl ++ "/content/blog/main.md"
        , expect = Http.expectString GotContent
        }


type Msg
    = GotContent (Result Http.Error String)
    | NavigateTo Page


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotContent result ->
            case result of
                Ok content ->
                    ( { model | markdownContent = content, status = Success }, renderMathJax () )

                Err error ->
                    ( { model | status = Failure error }, Cmd.none )

        NavigateTo page ->
            ( { model | currentPage = page }
            , renderMathJax ()
            )


getBlogPosts : Model -> List String
getBlogPosts model =
    case StringTrie.subtrie "/content/blog/" model.content of
        Just trie ->
            StringTrie.keys trie

        Nothing ->
            []


view : Model -> Html Msg
view model =
    div []
        [ viewNavBar model.currentPage
        , div [ class "container" ]
            [ viewContent model
            ]
        ]


viewNavBarItem : Page -> Page -> String -> Html Msg
viewNavBarItem currentPage page name =
    let
        activeClass =
            if currentPage == page then
                "navbar-item active"

            else
                "navbar-item"
    in
    li [ class activeClass ]
        [ a [ class "navbar-link", onClick (NavigateTo page) ] [ text name ] ]


viewNavBar : Page -> Html Msg
viewNavBar currentPage =
    nav [ class "navbar" ]
        [ ul [ class "navbar-items" ]
            [ viewNavBarItem currentPage Home "Home"
            , viewNavBarItem currentPage Blog "Blog"
            , viewNavBarItem currentPage Projects "Projects"
            ]
        ]


viewBlog : Model -> Html Msg
viewBlog model =
    case model.status of
        Loading ->
            div [ class "loading-display" ] [ h1 [] [ text "Loading content..." ] ]

        Success ->
            div [ class "content-display" ]
                [ toHtml [ class "markdown-content" ] model.markdownContent ]

        Failure _ ->
            div [ class "error-display" ] [ h1 [] [ text "Failed to load content. Please try again later." ] ]


viewHome : Model -> Html Msg
viewHome _ =
    div [ class "content-display" ]
        [ h1 [] [ text "Hello World" ]
        , p [] [ text "Welcome to my personal website!" ]
        ]


viewProjects : Model -> Html Msg
viewProjects _ =
    div [ class "content-display" ]
        [ h1 [] [ text "My Projects" ]
        , p [] [ text "This section will contain my projects." ]
        ]


viewContent : Model -> Html Msg
viewContent model =
    case model.currentPage of
        Home ->
            viewHome model

        Blog ->
            text (String.join "\n" (getBlogPosts model))

        Projects ->
            viewProjects model
