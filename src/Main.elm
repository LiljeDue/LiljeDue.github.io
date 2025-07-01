port module Main exposing (main)

import Browser
import Date exposing (Date)
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode exposing (Decoder)
import Markdown exposing (toHtml)
import StringTrie exposing (Trie)
import Task
import Time exposing (Month(..))


port renderMathJax : () -> Cmd msg


type Page
    = Home
    | Blogs
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
      , blogPosts = []
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

                Blogs ->
                    ( { model | currentPage = Blogs, status = Loading, markdownContent = "" }
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
    , date : Date
    , author : String
    , description : String
    }


type alias BlogPost =
    { meta : BlogMeta
    , url : String
    }


decodeDate : Decoder Date
decodeDate =
    Decode.string
        |> Decode.andThen
            (\dateString ->
                case Date.fromIsoString dateString of
                    Ok dateValue ->
                        Decode.succeed dateValue

                    Err _ ->
                        Decode.fail "Invalid date format"
            )


blogMetaDecoder : Decoder BlogMeta
blogMetaDecoder =
    Decode.map4 BlogMeta
        (Decode.field "title" Decode.string)
        (Decode.field "date" decodeDate)
        (Decode.field "author" Decode.string)
        (Decode.field "description" Decode.string)


parseBlogMeta : String -> Result Decode.Error BlogMeta
parseBlogMeta jsonString =
    Decode.decodeString blogMetaDecoder jsonString


decodeBlogMeta : String -> BlogMeta
decodeBlogMeta jsonString =
    case parseBlogMeta jsonString of
        Ok metadata ->
            metadata

        Err _ ->
            -- Provide default values when JSON parsing fails
            { title = "Untitled"
            , date = Date.fromCalendarDate 1970 Jan 1
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
        blogPath =
            "content/blog/"

        pathPredicate =
            (\n -> n /= 1)
                << String.length
                << String.filter (\x -> x == '\\')
                << String.dropLeft (String.length blogPath)

        isPost p =
            String.endsWith "/post.json" p
                || String.endsWith "/post.md" p

        files =
            StringTrie.expand blogPath trie
                |> List.map Tuple.first
                |> List.filter (\p -> isPost p && pathPredicate p)

        ( blogs, metas ) =
            files
                |> List.map (\s -> contentBaseUrl ++ "/" ++ s)
                |> List.partition (\s -> String.endsWith "/post.md" s)
    in
    if List.length blogs == List.length metas then
        httpGets
            { urls = metas
            , toMesage =
                \result ->
                    case result of
                        Ok jsonStrings ->
                            GotBlogPosts
                                (Ok
                                    (List.map2 (\url json -> { meta = decodeBlogMeta json, url = url }) blogs jsonStrings
                                        |> List.sortWith (\p0 p1 -> Date.compare p1.meta.date p0.meta.date)
                                    )
                                )

                        Err error ->
                            GotBlogPosts (Err error)
            }

    else
        Cmd.none


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
            , viewNavBarItem currentPage Blogs "Blog"
            , viewNavBarItem currentPage Projects "Projects"
            ]
        ]


viewBlog : Model -> Html Msg
viewBlog model =
    case model.status of
        Loading ->
            div [ class "loading-display" ] [ h1 [] [ text "Loading blog..." ] ]

        Success ->
            div [ class "content-display" ]
                [ toHtml [ class "markdown-content" ] model.markdownContent ]

        Failure _ ->
            div [ class "error-display" ] [ h1 [] [ text "Failed to load blog. Please try again later." ] ]


viewHome : Model -> Html Msg
viewHome _ =
    div [ class "content-display" ]
        [ p [] [ text "Welcome to my personal website!" ]
        ]


viewProjects : Model -> Html Msg
viewProjects _ =
    div [ class "content-display" ]
        [ p [] [ text "This section will contain my projects." ]
        ]


viewBlogCard : BlogPost -> Html Msg
viewBlogCard post =
    div [ class "blog-card" ]
        [ div []
            [ h1 [] [ text post.meta.title ]
            , p [] [ text (Date.format "d MMMM y" post.meta.date) ]
            , br [] []    
            , p [] [ text post.meta.description ]
            ]
        ]


viewBlogPosts : Model -> Html Msg
viewBlogPosts model =
    case model.status of
        Loading ->
            div [ class "loading-display" ] [ h1 [] [ text "Loading blog posts..." ] ]

        Success ->
            div [ class "content-display" ]
                (List.map viewBlogCard model.blogPosts)

        Failure _ ->
            div [ class "error-display" ] [ h1 [] [ text "Failed to load blog posts. Please try again later." ] ]


viewContent : Model -> Html Msg
viewContent model =
    case model.currentPage of
        Home ->
            viewHome model

        Blogs ->
            viewBlogPosts model

        Projects ->
            viewProjects model
