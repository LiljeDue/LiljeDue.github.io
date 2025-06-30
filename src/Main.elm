port module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Json.Decode exposing (Decoder, decodeString, field, string)
import Markdown exposing (toHtml)
import StringTrie exposing (Trie)
import Task


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
    , blogPosts : List BlogPost
    }


type Status
    = Loading
    | Success
    | Failure Http.Error


init : Parameters -> ( Model, Cmd Msg )
init params =
    let
        trie =
            StringTrie.fromList (List.map (\s -> ( s, () )) params.content)
    in
    ( { content = trie
      , markdownContent = ""
      , baseContentUrl = params.baseContentUrl
      , status = Loading
      , currentPage = Home
      , blogPosts = [] -- getBlogPosts params.baseContentUrl trie
      }
    , Cmd.none
    )


type Msg
    = GotMarkdown (Result Http.Error String)
    | GotBlogPosts (Result Http.Error (List BlogPost))
    | NavigateTo Page


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotMarkdown result ->
            case result of
                Ok content ->
                    ( { model | markdownContent = content, status = Success }, renderMathJax () )

                Err error ->
                    ( { model | status = Failure error }, Cmd.none )

        NavigateTo page ->
            case page of
                Home ->
                    ( { model | currentPage = Home, status = Loading, markdownContent = "" }
                    , Cmd.none
                    )

                Blog ->
                    ( { model | currentPage = Blog, status = Loading, markdownContent = "" }
                    , fetchBlogPosts model.baseContentUrl model.content
                    )

                Projects ->
                    ( { model | currentPage = Projects, status = Loading, markdownContent = "" }
                    , Cmd.none
                    )

        GotBlogPosts result ->
            case result of
                Ok posts ->
                    ( { model | blogPosts = posts, status = Success }, Cmd.none )

                Err error ->
                    ( { model | status = Failure error }, Cmd.none )


type alias BlogMeta =
    { title : String
    , date : String
    , author : String
    , description : String
    }


type alias BlogPost =
    { meta : BlogMeta
    , url : String
    }


blogMetaDecoder : Decoder BlogMeta
blogMetaDecoder =
    Json.Decode.map4 BlogMeta
        (field "title" string)
        (field "date" string)
        (field "author" string)
        (field "description" string)


parseBlogMeta : String -> Result Json.Decode.Error BlogMeta
parseBlogMeta jsonString =
    decodeString blogMetaDecoder jsonString


processMetadata : String -> BlogMeta
processMetadata jsonString =
    case parseBlogMeta jsonString of
        Ok metadata ->
            metadata

        Err _ ->
            -- Provide default values when JSON parsing fails
            { title = "Untitled"
            , date = "Unknown date"
            , author = "Unknown author"
            , description = "No description available"
            }


httpGets : { urls : List String, toMesage : Result Http.Error (List String) -> msg } -> Cmd msg
httpGets request =
    request.urls
        |> List.map
            (\url ->
                Http.task
                    { url = url
                    , method = "GET"
                    , headers = []
                    , body = Http.emptyBody
                    , resolver =
                        Http.stringResolver
                            (\response ->
                                case response of
                                    Http.GoodStatus_ _ body ->
                                        Ok body

                                    _ ->
                                        Err (Http.BadBody "Failed to get meta file")
                            )
                    , timeout = Nothing
                    }
            )
        |> Task.sequence
        |> Task.attempt request.toMesage


fetchBlogPosts : String -> Trie () -> Cmd Msg
fetchBlogPosts contentBaseUrl trie =
    let
        files =
            StringTrie.expand "content/blog/" trie
                |> List.map Tuple.first

        auxiliary suffix path =
            List.filter (String.endsWith suffix) path
                |> List.filter (not << String.contains "/" << String.dropRight (String.length suffix))

        mainPosts =
            auxiliary "/main.md" files
                |> List.map (\s -> contentBaseUrl ++ "/" ++ s)
    in
    httpGets
        { urls = auxiliary "/meta.json" files
        , toMesage =
            \result ->
                case result of
                    Ok jsonStrings ->
                        GotBlogPosts (Ok (List.map2 (\url json -> { meta = processMetadata json, url = url }) mainPosts jsonStrings))

                    Err error ->
                        GotBlogPosts (Err error)
        }


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


viewBlogPosts : Model -> Html Msg
viewBlogPosts model =
    case model.status of
        Loading ->
            div [ class "loading-display" ] [ h1 [] [ text "Loading blog posts..." ] ]

        Success ->
            div []
                (List.map
                    (\post -> text post.meta.title)
                    model.blogPosts
                )

        Failure _ ->
            div [ class "error-display" ] [ h1 [] [ text "Failed to load blog posts. Please try again later." ] ]


viewContent : Model -> Html Msg
viewContent model =
    case model.currentPage of
        Home ->
            viewHome model

        Blog ->
            -- list meta and posts
            viewBlogPosts model

        Projects ->
            viewProjects model
