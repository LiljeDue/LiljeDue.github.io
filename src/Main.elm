port module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Json.Decode exposing (Decoder, decodeString, field, string)
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
      , blogPosts = getBlogPosts params.baseContentUrl trie
      }
    , Cmd.none
    )


fetchMarkdown : Model -> String -> Cmd Msg
fetchMarkdown model path =
    Http.get
        { url = model.baseContentUrl ++ "/" ++ path
        , expect = Http.expectString Markdown
        }


type Msg
    = GotMarkdown (Result Http.Error String)
    | NavigateTo Page
    | GotMetadata (Result Http.Error String) -- New message type


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
            ( { model | currentPage = page }
            , renderMathJax ()
            )

        GotMetadata result ->
            case result of
                Ok jsonString ->
                    ( { model | blogMetadata = Just (processMetadata jsonString) }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )


type alias BlogMeta =
    { title : String
    , date : String
    , author : String
    , description : String
    }


type alias BlogPost =
    { meta : BlogMeta
    , content : String
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


getBlogPosts : String -> Trie () -> List BlogPost
getBlogPosts contentBaseUrl trie =
    let
        contentSuffix =
            "/main.md"

        metaSuffix =
            "/meta.json"

        files =
            StringTrie.expand "content/blog/" trie
                |> List.map Tuple.first

        auxiliary suffix path =
            List.filter (String.endsWith suffix) path
                |> List.filter (not << String.contains "/" << String.dropRight (String.length suffix))

        metas =
            auxiliary metaSuffix files
                |> List.map (\s -> contentBaseUrl ++ "/" ++ s)
                |> List.map processMetadata

        mainPosts =
            auxiliary contentSuffix files
                |> List.map (\s -> contentBaseUrl ++ "/" ++ s)
    in
    List.map2 (\content meta -> { meta = meta, content = content }) mainPosts metas


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


fetchMetadata : Model -> String -> Cmd Msg
fetchMetadata model path =
    Http.get
        { url = model.baseContentUrl ++ "/" ++ path ++ "/meta.json"
        , expect = Http.expectString GotMetadata
        }


viewBlogWithMetadata : Model -> Html Msg
viewBlogWithMetadata model =
    let
        metadataView =
            case model.blogMetadata of
                Just meta ->
                    div [ class "blog-metadata" ]
                        [ h1 [] [ text meta.title ]
                        , div [ class "blog-info" ]
                            [ span [ class "date" ] [ text meta.date ]
                            , span [ class "author" ] [ text ("by " ++ meta.author) ]
                            ]
                        , p [ class "description" ] [ text meta.description ]
                        ]

                Nothing ->
                    div [] []
    in
    div [ class "content-display" ]
        [ metadataView
        , case model.status of
            Loading ->
                div [ class "loading-display" ] [ h1 [] [ text "Loading content..." ] ]

            Success ->
                div [ class "blog-content" ]
                    [ toHtml [ class "markdown-content" ] model.markdownContent ]

            Failure _ ->
                div [ class "error-display" ] [ h1 [] [ text "Failed to load content. Please try again later." ] ]
        ]
