module Model exposing
    ( Model
    , Msg(..)
    , Page(..)
    , Parameters
    , ProjectMeta
    , ProjectPost
    , Status(..)
    , fromUrl
    , routeParser
    )

import Blog exposing (..)
import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Http
import StringTrie exposing (Trie)
import Url
import Url.Parser as Parser exposing ((</>), Parser)


type Page
    = Home
    | Blogs
    | Supervison
    | Blog String
    | NotFound


type alias Parameters =
    { baseContentUrl : String
    , content : List String
    }


type alias ProjectMeta =
    { title : String
    , description : String
    }


type alias ProjectPost =
    { meta : ProjectMeta
    , url : String
    , href : String
    }


type alias Model =
    { content : Trie ()
    , projectIntroContent : String
    , projectMarkdownContent : String
    , baseContentUrl : String
    , status : Status
    , projectsStatus : Status
    , projectModalStatus : Status
    , currentPage : Page
    , blogPosts : Dict String BlogPost
    , projectPosts : Dict String ProjectPost
    , openProject : Maybe String
    , key : Nav.Key
    , url : Url.Url
    }


type Status
    = Loading
    | Success
    | Failure Http.Error


type Msg
    = GotBlogPosts (Result Http.Error (Dict String BlogPost))
    | GotProjectPosts (Result Http.Error (Dict String ProjectPost))
    | GotProjectIntro (Result Http.Error String)
    | GotProjectMarkdown (Result Http.Error String)
    | OpenProject String
    | CloseProject
    | NoOp
    | NavigateTo Page
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url


routeParser : Parser (Page -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Home Parser.top
        , Parser.map Home (Parser.s "home")
        , Parser.map Blogs (Parser.s "blog")
        , Parser.map Supervison (Parser.s "supervison")
        , Parser.map Blog (Parser.s "blog" </> Parser.string)
        ]


fromUrl : Url.Url -> Page
fromUrl url =
    case Parser.parse routeParser url of
        Just page ->
            page

        Nothing ->
            NotFound
