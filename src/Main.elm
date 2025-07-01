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
import Browser
import Browser.Navigation as Nav
import Url
import Url.Parser as Parser exposing (Parser, (</>))


port renderMathJax : () -> Cmd msg


type Page
    = Home
    | Blogs
    | Projects
    | Blog BlogPost


type alias Parameters =
    { baseContentUrl : String
    , content : List String
    }

type alias Model =
    { content : Trie ()
    , markdownContent : String
    , baseContentUrl : String
    , status : Status
    , currentPage : Page
    , blogPosts : List BlogPost
    , key : Nav.Key
    , url : Url.Url
    }


type Status
    = Loading
    | Success
    | Failure Http.Error

type Msg
    = GotMarkdown (Result Http.Error String)
    | GotBlogPosts (Result Http.Error (List BlogPost))
    | NavigateTo Page
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url

main : Program Parameters Model Msg
main =
    Browser.application
        { init = init
        , view = \model -> { title = "My Website", body = [view model] }
        , update = update
        , subscriptions = \_ -> Sub.none
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



routeParser : Parser (Page -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Home Parser.top
        , Parser.map Home (Parser.s "home")
        , Parser.map Blogs (Parser.s "blogs")
        , Parser.map Projects (Parser.s "projects")
        ]

fromUrl : Url.Url -> Page
fromUrl url =
    case Parser.parse routeParser url of
        Just page ->
            page
        Nothing ->
            Home

init : Parameters -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init params url key =
    let
        trie =
            StringTrie.fromList (List.map (\s -> ( s, () )) params.content)
        
        initialPage = fromUrl url
    in
    ( { content = trie
      , markdownContent = ""
      , baseContentUrl = params.baseContentUrl
      , status = Loading
      , currentPage = initialPage
      , blogPosts = []
      , key = key
      , url = url
      }
    , case initialPage of
        Blogs -> fetchBlogPosts params.baseContentUrl trie
        _ -> Cmd.none
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotMarkdown result ->
            case result of
                Ok content ->
                    ( { model | markdownContent = content, status = Success }, renderMathJax () )

                Err error ->
                    ( { model | status = Failure error }, Cmd.none )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            let
                newPage = fromUrl url
            in
            ( { model | url = url, currentPage = newPage, status = Loading, markdownContent = "" }
            , case newPage of
                Blogs -> fetchBlogPosts model.baseContentUrl model.content
                Blog post -> Http.get
                    { url = post.url
                    , expect = Http.expectString GotMarkdown
                    }
                _ -> Cmd.none
            )

        NavigateTo page ->
            let
                url = case page of
                    Home -> "/"
                    Blogs -> "/blogs"
                    Projects -> "/projects"
                    Blog post -> "/blog/" ++ post.href
            in
            ( model, Nav.pushUrl model.key url )

        GotBlogPosts result ->
            case result of
                Ok blogPosts ->
                    ( { model | blogPosts = blogPosts, status = Success }, Cmd.none )

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
    , href : String
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
                |> List.partition (\s -> String.endsWith "/post.md" s)

        href =
            String.dropLeft (String.length blogPath)
            << String.dropRight (String.length "/post.md")
    in
    if List.length blogs == List.length metas then
        httpGets
            { urls = List.map (\s -> contentBaseUrl ++ "/" ++ s) metas
            , toMesage =
                \result ->
                    case result of
                        Ok jsonStrings ->
                            GotBlogPosts
                                (Ok
                                    (List.map2 (\url json ->
                                    { meta = decodeBlogMeta json
                                    , url = contentBaseUrl ++ "/" ++ url
                                    , href = href url
                                     }) blogs jsonStrings
                                        |> List.sortWith (\p0 p1 -> Date.compare p1.meta.date p0.meta.date)
                                    )
                                )

                        Err error ->
                            GotBlogPosts (Err error)
            }

    else
        Cmd.none


viewPage : Model -> Html Msg -> Html Msg
viewPage model page =
    case model.status of
        Loading ->
            div [ class "loading-display" ] [ h1 [] [ text "Loading blog post..." ] ]
        Success ->
            div [ class "content-display" ]
                [ page ]
        Failure _ ->
            div [ class "error-display" ] [ h1 [] [ text "Failed to load blog post. Please try again later." ] ]   


view : Model -> Html Msg
view model =
    div []
        [ viewNavBar model.currentPage
        , div [ class "container" ]
            [ viewContent model
            ]
        ]


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
            , viewNavBarItem currentPage Blogs "Blog" "/blogs"
            , viewNavBarItem currentPage Projects "Projects" "/projects"
            ]
        ]

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
    div [ class "blog-card", Html.Attributes.href post.href, onClick (NavigateTo (Blog post)) ]
        [ div []
            [ h1 [] [ text post.meta.title ]
            , p [] [ text (Date.format "d MMMM y" post.meta.date) ]
            , br [] []    
            , p [] [ text post.meta.description ]
            ]
        ]


viewBlogPosts : Model -> Html Msg
viewBlogPosts model =
    viewPage model (div [  ] (List.map viewBlogCard model.blogPosts))

viewBlog : Model -> BlogPost -> Html Msg
viewBlog model post =
    viewPage model (div [ ]
                [ h1 [] [ text post.meta.title ]
                , p [] [ text (Date.format "d MMMM y" post.meta.date) ]
                , br [] []
                , toHtml [ class "markdown-content" ] model.markdownContent
                ])



viewContent : Model -> Html Msg
viewContent model =
    case model.currentPage of
        Home ->
            viewHome model

        Blogs ->
            viewBlogPosts model

        Projects ->
            viewProjects model

        Blog post ->
            viewBlog model post 
