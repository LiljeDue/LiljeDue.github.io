module Main exposing (main)

import Blog exposing (..)
import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (class)
import Http
import Json.Decode as Decode
import Model exposing (..)
import StringTrie exposing (Trie)
import Url
import Views.Blog exposing (..)
import Views.Home exposing (..)
import Views.NavBar exposing (viewNavBar)
import Views.NotFound exposing (viewNotFound)
import Views.Supervison exposing (viewSupervison)


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


projectMetaDecoder : Decode.Decoder ProjectMeta
projectMetaDecoder =
    Decode.map2 ProjectMeta
        (Decode.field "title" Decode.string)
        (Decode.field "description" Decode.string)


projectPath : String
projectPath =
    "projects/"


projectMarkdownSuffix : String
projectMarkdownSuffix =
    "/project.md"


projectJsonSuffix : String
projectJsonSuffix =
    "/project.json"


extractProjectFiles : Trie () -> { markdownFiles : List String, metaFiles : List String }
extractProjectFiles trie =
    let
        allFiles =
            StringTrie.expand projectPath trie
                |> List.map Tuple.first
                |> List.sort

        markdownFiles =
            List.filter (String.endsWith projectMarkdownSuffix) allFiles

        metaFiles =
            List.filter (String.endsWith projectJsonSuffix) allFiles
    in
    { markdownFiles = markdownFiles, metaFiles = metaFiles }


buildProjectHref : String -> String
buildProjectHref path =
    path
        |> String.dropLeft (String.length projectPath)
        |> String.dropRight (String.length projectMarkdownSuffix)


buildProjectPostDict : String -> List String -> List String -> Dict String ProjectPost
buildProjectPostDict contentBaseUrl markdownFiles jsonStrings =
    List.map2
        (\mdPath jsonStr ->
            let
                meta =
                    Decode.decodeString projectMetaDecoder jsonStr
                        |> Result.withDefault { title = "Untitled", description = "" }

                href =
                    buildProjectHref mdPath
            in
            ( href
            , { meta = meta
              , url = buildContentUrl contentBaseUrl mdPath
              , href = href
              }
            )
        )
        markdownFiles
        jsonStrings
        |> Dict.fromList


handleProjectPostsResponse : String -> List String -> Result Http.Error (List String) -> Msg
handleProjectPostsResponse contentBaseUrl markdownFiles result =
    result
        |> Result.map (buildProjectPostDict contentBaseUrl markdownFiles)
        |> GotProjectPosts


fetchProjectPosts : String -> Trie () -> Cmd Msg
fetchProjectPosts contentBaseUrl trie =
    let
        { markdownFiles, metaFiles } =
            extractProjectFiles trie
    in
    if List.isEmpty metaFiles then
        Cmd.none

    else
        httpGets
            { urls = List.map (buildContentUrl contentBaseUrl) metaFiles
            , toMesage = handleProjectPostsResponse contentBaseUrl markdownFiles
            }


fetchProjectIntro : String -> Cmd Msg
fetchProjectIntro contentBaseUrl =
    Http.get
        { url = buildContentUrl contentBaseUrl "projects/intro.md"
        , expect = Http.expectString GotProjectIntro
        }


main : Program Parameters Model Msg
main =
    Browser.application
        { init = init
        , view = \model -> { title = "Lilje Due", body = [ view model ] }
        , update = update
        , subscriptions = \_ -> Sub.none
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


{-| Blog posts are static pages built by pandoc, so opening one is a full page
load rather than an in-app navigation.
-}
blogPostUrl : String -> String
blogPostUrl href =
    "/blog/" ++ href ++ "/"


urlChanged : Model -> Url.Url -> ( Model, Cmd Msg )
urlChanged model url =
    ( { model | url = url, currentPage = fromUrl url }, Cmd.none )


navigateTo : Model -> Page -> ( Model, Cmd Msg )
navigateTo model page =
    let
        url =
            case page of
                Home ->
                    "/"

                Blogs ->
                    "/blog"

                Supervison ->
                    "/supervison"

                Blog post ->
                    blogPostUrl post

                NotFound ->
                    "/not-found"
    in
    case page of
        Blog _ ->
            ( model, Nav.load url )

        _ ->
            ( model, Nav.pushUrl model.key url )


linkClicked : Model -> Browser.UrlRequest -> ( Model, Cmd Msg )
linkClicked model urlRequest =
    case urlRequest of
        Browser.Internal url ->
            case fromUrl url of
                Blog _ ->
                    ( model, Nav.load (Url.toString url) )

                _ ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

        Browser.External href ->
            ( model, Nav.load href )


gotBlogPosts : Model -> Result Http.Error (Dict String BlogPost) -> ( Model, Cmd Msg )
gotBlogPosts model result =
    case result of
        Ok blogPosts ->
            ( { model | blogPosts = blogPosts, status = Success }, Cmd.none )

        Err error ->
            ( { model | status = Failure error }, Cmd.none )


gotProjectPosts : Model -> Result Http.Error (Dict String ProjectPost) -> ( Model, Cmd Msg )
gotProjectPosts model result =
    case result of
        Ok projectPosts ->
            ( { model | projectPosts = projectPosts, projectsStatus = Success }, Cmd.none )

        Err error ->
            ( { model | projectsStatus = Failure error }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            linkClicked model urlRequest

        UrlChanged url ->
            urlChanged model url

        NavigateTo page ->
            navigateTo model page

        GotBlogPosts result ->
            gotBlogPosts model result

        GotProjectPosts result ->
            gotProjectPosts model result

        GotProjectIntro result ->
            case result of
                Ok content ->
                    ( { model | projectIntroContent = content }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        OpenProject href ->
            case Dict.get href model.projectPosts of
                Just post ->
                    ( { model | openProject = Just href, projectModalStatus = Loading, projectMarkdownContent = "" }
                    , Http.get
                        { url = post.url
                        , expect = Http.expectString GotProjectMarkdown
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        GotProjectMarkdown result ->
            case result of
                Ok content ->
                    ( { model | projectMarkdownContent = content, projectModalStatus = Success }, Cmd.none )

                Err error ->
                    ( { model | projectModalStatus = Failure error }, Cmd.none )

        CloseProject ->
            ( { model | openProject = Nothing, projectMarkdownContent = "" }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


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

        Supervison ->
            viewSupervison model

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
      , projectIntroContent = ""
      , projectMarkdownContent = ""
      , baseContentUrl = params.baseContentUrl
      , status = Loading
      , projectsStatus = Loading
      , projectModalStatus = Loading
      , currentPage = initialPage
      , blogPosts = Dict.empty
      , projectPosts = Dict.empty
      , openProject = Nothing
      , key = key
      , url = url
      }
    , Cmd.batch
        [ fetchBlogPosts params.baseContentUrl trie
        , fetchProjectPosts params.baseContentUrl trie
        , fetchProjectIntro params.baseContentUrl
        ]
    )
