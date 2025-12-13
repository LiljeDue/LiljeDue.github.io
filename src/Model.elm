module Model exposing
    ( Model
    , Msg(..)
    , Page(..)
    , Parameters
    , Status(..)
    , fromUrl
    , routeParser
    )

import Blog exposing (..)
import Browser
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (..)
import Http
import StringTrie exposing (Trie)
import Time exposing (Month(..))
import Url
import Url.Parser as Parser exposing ((</>), Parser)


type Page
    = Home
    | Blogs
    | Projects
    | Blog String
    | NotFound


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
    , blogPosts : Dict String BlogPost
    , key : Nav.Key
    , url : Url.Url
    }


type Status
    = Loading
    | Success
    | Failure Http.Error


type Msg
    = GotMarkdown (Result Http.Error String)
    | GotBlogPosts (Result Http.Error (Dict String BlogPost))
    | NavigateTo Page
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url


routeParser : Parser (Page -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Home Parser.top
        , Parser.map Home (Parser.s "home")
        , Parser.map Blogs (Parser.s "blog")
        , Parser.map Projects (Parser.s "projects")
        , Parser.map Blog (Parser.s "blog" </> Parser.string)
        ]


fromUrl : Url.Url -> Page
fromUrl url =
    case Parser.parse routeParser url of
        Just page ->
            page

        Nothing ->
            NotFound
