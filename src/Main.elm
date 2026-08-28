port module Main exposing (main)

import Blog exposing (..)
import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (class)
import Http
import Model exposing (..)
import StringTrie exposing (Trie)
import Time exposing (Month(..))
import Url
import Views.Blog exposing (..)
import Views.Home exposing (..)
import Views.NavBar exposing (viewNavBar)
import Views.NotFound exposing (viewNotFound)
import Views.Projects exposing (viewProjects)


port renderMathJax : () -> Cmd msg


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


loadBlogPost : String -> Model -> ( Model, Cmd Msg )
loadBlogPost href model =
    case Dict.get href model.blogPosts of
        Just post ->
            ( { model | status = Loading }
            , Http.get
                { url = post.url
                , expect = Http.expectString GotMarkdown
                }
            )

        Nothing ->
            ( model, Cmd.none )


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
            loadBlogPost href newModel

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

                NotFound ->
                    "/not-found"
    in
    ( model, Nav.pushUrl model.key url )


linkClicked : Model -> Browser.UrlRequest -> ( Model, Cmd Msg )
linkClicked model urlRequest =
    case urlRequest of
        Browser.Internal url ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        Browser.External href ->
            ( model, Nav.load href )


gotMarkdown : Model -> Result Http.Error String -> ( Model, Cmd Msg )
gotMarkdown model result =
    case result of
        Ok content ->
            ( { model | markdownContent = content, status = Success }, renderMathJax () )

        Err error ->
            ( { model | status = Failure error }, Cmd.none )


gotBlogPosts : Model -> Result Http.Error (Dict String BlogPost) -> ( Model, Cmd Msg )
gotBlogPosts model result =
    case result of
        Ok blogPosts ->
            let
                newModel =
                    { model | blogPosts = blogPosts, status = Success }
            in
            case model.currentPage of
                Blog href ->
                    loadBlogPost href newModel

                _ ->
                    ( newModel, Cmd.none )

        Err error ->
            ( { model | status = Failure error }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotMarkdown result ->
            gotMarkdown model result

        LinkClicked urlRequest ->
            linkClicked model urlRequest

        UrlChanged url ->
            urlChanged model url

        NavigateTo page ->
            navigateTo model page

        GotBlogPosts result ->
            gotBlogPosts model result


view : Model -> Html Msg
view model =
    div []
        [ viewNavBar model.currentPage
        , div [ class "container" ]
            [ viewContent model
            ]
        ]


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

        NotFound ->
            viewNotFound model


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
