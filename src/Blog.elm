module Blog exposing (..)

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

blogPostFiles : Trie () -> BlogPostFiles 
blogPostFiles trie =
    let
        blogFiles =
            extractBlogFiles trie
            
    in
      partitionBlogFiles blogFiles

-- Types for better clarity
type BlogPostFiles
    = ValidBlogPosts { markdownFiles : List String, metaFiles : List String }
    | MismatchedBlogPosts


-- Constants
blogPath :  String
blogPath =
    "content/blog/"


postMarkdownSuffix : String
postMarkdownSuffix =
    "/post.md"


postJsonSuffix : String
postJsonSuffix =
    "/post.json"


-- Extract all blog files from the trie
extractBlogFiles : Trie () -> List String
extractBlogFiles trie =
    StringTrie.expand blogPath trie
        |> List.map Tuple.first
        |> List.filter isBlogPostFile


-- Check if a file is a blog post (markdown or json)
isBlogPostFile : String -> Bool
isBlogPostFile path =
    isDirectBlogPost path && isBlogPost path


-- Check if the file is directly in a blog post directory (not nested)
isDirectBlogPost : String -> Bool
isDirectBlogPost path =
    let
        relativePath =
            String.dropLeft (String.length blogPath) path
        
        backslashCount =
            relativePath
                |> String.filter (\c -> c == '\\')
                |> String.length
    in
    backslashCount /= 1


-- Check if the file is either post.md or post.json
isBlogPost : String -> Bool
isBlogPost path =
    String.endsWith postMarkdownSuffix path
        || String.endsWith postJsonSuffix path


-- Partition files into markdown and meta files, validating counts
partitionBlogFiles : List String -> BlogPostFiles
partitionBlogFiles files =
    let
        ( markdownFiles, metaFiles ) =
            List.partition (String.endsWith postMarkdownSuffix) files
    in
    if List.length markdownFiles == List.length metaFiles then
        ValidBlogPosts
            { markdownFiles = markdownFiles
            , metaFiles = metaFiles
            }
    else
        MismatchedBlogPosts


httpGets : { urls : List String, toMesage : Result Http.Error (List String) -> msg } -> Cmd msg
httpGets request =
    let
        resolver =
            Http.stringResolver
                (\response ->
                    case response of
                        Http.GoodStatus_ _ body ->
                            Ok body

                        _ ->
                            Err (Http.BadBody "Failed to get meta file")
                )
    in
    request.urls
        |> List.map
            (\url ->
                Http.task
                    { url = url
                    , method = "GET"
                    , headers = []
                    , body = Http.emptyBody
                    , resolver = resolver
                    , timeout = Nothing
                    }
            )
        |> Task.sequence
        |> Task.attempt request.toMesage

-- Build full URL for content
buildContentUrl : String -> String -> String
buildContentUrl baseUrl path =
    baseUrl ++ "/" ++ path




-- Build a dictionary of blog posts from markdown files and JSON metadata
buildBlogPostDict :  String -> List String -> List String -> Dict String BlogPost
buildBlogPostDict contentBaseUrl markdownFiles jsonStrings =
    List.map2 (createBlogPost contentBaseUrl) markdownFiles jsonStrings
        |> List.map (\post -> ( post.href, post ))
        |> Dict.fromList



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


createBlogPost : String -> String -> String -> BlogPost
createBlogPost contentBaseUrl markdownPath json =
    { meta = decodeBlogMeta json
    , url = buildContentUrl contentBaseUrl markdownPath
    , href = extractBlogHref markdownPath
    }

extractBlogHref : String -> String
extractBlogHref path =
    path
        |> String.dropLeft (String.length blogPath)
        |> String.dropRight (String.length postMarkdownSuffix)