port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Date exposing (Date)
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode exposing (Decoder)
import Markdown exposing (toHtml)
import StringTrie exposing (Trie)
import Task
import Time exposing (Month(..))
import Url
import Url.Parser as Parser exposing ((</>), Parser)
import Model exposing (..)
import Blog exposing (..)


port renderMathJax : () -> Cmd msg



-- Handle the HTTP response for blog posts
handleBlogPostsResponse : String -> List String -> Result Http.Error (List String) -> Msg
handleBlogPostsResponse contentBaseUrl markdownFiles result =
    result
        |> Result.map (buildBlogPostDict contentBaseUrl markdownFiles)
        |> GotBlogPosts


fetchBlogPosts : String -> Trie () -> Cmd Msg
fetchBlogPosts contentBaseUrl trie =
    case blogPostFiles trie of
        ValidBlogPosts posts ->
            fetchBlogMetadata contentBaseUrl posts
        
        MismatchedBlogPosts ->
            Cmd.none



-- Fetch metadata for all blog posts
fetchBlogMetadata : String -> { markdownFiles : List String, metaFiles : List String } -> Cmd Msg
fetchBlogMetadata contentBaseUrl { markdownFiles, metaFiles } =
    httpGets
        { urls = List.map (buildContentUrl contentBaseUrl) metaFiles
        , toMesage = handleBlogPostsResponse contentBaseUrl markdownFiles
        }


main : Program Parameters Model Msg
main =
    Browser.application
        { init = init
        , view = \model -> { title = "Due's Website", body = [ view model ] }
        , update = update
        , subscriptions = \_ -> Sub.none
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


urlChanged : Model -> Url.Url -> ( Model, Cmd Msg )
urlChanged model url =
    let
        newPage =
            fromUrl url

        newModel =
            { model | url = url, currentPage = newPage }
    in
    case newPage of
        Blog href ->
            case Dict.get href model.blogPosts of
                Just post ->
                    ( { newModel | status = Loading }
                    , Http.get
                        { url = post.url
                        , expect = Http.expectString GotMarkdown
                        }
                    )

                Nothing ->
                    ( newModel, Cmd.none )

        _ ->
            ( newModel, Cmd.none )


navigateTo : Model -> Page -> ( Model, Cmd Msg )
navigateTo model page =
    let
        url =
            case page of
                Home ->
                    "/"

                Blogs ->
                    "/blog"

                Projects ->
                    "/projects"

                Blog post ->
                    "/blog/" ++ post
    in
    ( model, Nav.pushUrl model.key url )


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
            urlChanged model url

        NavigateTo page ->
            navigateTo model page

        GotBlogPosts result ->
            case result of
                Ok blogPosts ->
                    let
                        newModel =
                            { model | blogPosts = blogPosts }

                        ( finalModel, cmd ) =
                            case model.currentPage of
                                Blog href ->
                                    case Dict.get href blogPosts of
                                        Just post ->
                                            ( { newModel | status = Loading }
                                            , Http.get
                                                { url = post.url
                                                , expect = Http.expectString GotMarkdown
                                                }
                                            )

                                        Nothing ->
                                            ( { newModel | status = Success }, Cmd.none )

                                _ ->
                                    ( { newModel | status = Success }, Cmd.none )
                    in
                    ( finalModel, cmd )

                Err error ->
                    ( { model | status = Failure error }, Cmd.none )


viewPage : Model -> Html Msg -> Html Msg
viewPage model page =
    case model.status of
        Loading ->
            div [ class "loading-display" ] [ h1 [] [ text "Loading blog post..." ] ]

        Success ->
            div [ class "content-display" ]
                [ page ]

        Failure _ ->
            div [ class "error-display" ] [ h1 [] [ text "Failed to load content. Please try again later." ] ]


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
            , viewNavBarItem currentPage Blogs "Blog" "/blog"
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
    div [ class "blog-card", Html.Attributes.href post.href, onClick (NavigateTo (Blog post.href)) ]
        [ div []
            [ h1 [] [ text post.meta.title ]
            , p [] [ text (Date.format "d MMMM y" post.meta.date) ]
            , br [] []
            , p [] [ text post.meta.description ]
            ]
        ]


viewBlogPosts : Model -> Html Msg
viewBlogPosts model =
    let
        blogPosts =
            Dict.values model.blogPosts
                |> List.sortWith (\p0 p1 -> Date.compare p1.meta.date p0.meta.date)
                |> List.map viewBlogCard
    in
    viewPage model (div [] blogPosts)


viewBlog : Model -> String -> Html Msg
viewBlog model href =
    case Dict.get href model.blogPosts of
        Nothing ->
            viewPage model (div [] [ text "Blog post not found." ])

        Just post ->
            viewPage model
                (div []
                    [ h1 [] [ text post.meta.title ]
                    , p [] [ text (Date.format "d MMMM y" post.meta.date) ]
                    , br [] []
                    , toHtml [ class "markdown-content" ] model.markdownContent
                    ]
                )


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


init : Parameters -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init params url key =
    let
        trie =
            StringTrie.fromList (List.map (\s -> ( s, () )) params.content)

        initialPage =
            fromUrl url
    in
    ( { content = trie
      , markdownContent = ""
      , baseContentUrl = params.baseContentUrl
      , status = Loading
      , currentPage = initialPage
      , blogPosts = Dict.empty
      , key = key
      , url = url
      }
    , fetchBlogPosts params.baseContentUrl trie
    )