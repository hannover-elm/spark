module Main exposing (..)

import Base64
import Browser
import Html exposing (Html, text)
import Html.Attributes exposing (style)
import Html.Events
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Random exposing (Generator)


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type Model
    = Generating { token : String }
    | Writing
        { baseName : String
        , content : String
        , token : String
        }
    | Sending
        { baseName : String
        , content : String
        , token : String
        }
    | Failing
        { baseName : String
        , content : String
        , token : String
        , httpError : Http.Error
        }


type Msg
    = NoteCreated (Result Http.Error ())
    | CreateNoteClicked
    | BaseNameChanged String
    | ContentChanged String
    | TokenChanged String
    | FileNameGenerated String


repo =
    "hannover-elm/spark"


init : () -> ( Model, Cmd Msg )
init flags =
    ( Generating { token = "" }, generateFileName )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( model, msg ) of
        ( Generating data, FileNameGenerated newBaseName ) ->
            ( Writing { baseName = newBaseName, content = "", token = data.token }
            , Cmd.none
            )

        ( Generating _, _ ) ->
            ( model, Cmd.none )

        ( Writing data, BaseNameChanged newBaseName ) ->
            ( Writing { data | baseName = newBaseName }, Cmd.none )

        ( Writing data, ContentChanged newContent ) ->
            ( Writing { data | content = newContent }, Cmd.none )

        ( Writing data, TokenChanged newToken ) ->
            ( Writing { data | token = newToken }, Cmd.none )

        ( Writing data, CreateNoteClicked ) ->
            ( Sending data
            , createNote data.token data.baseName data.content
            )

        ( Writing _, _ ) ->
            ( model, Cmd.none )

        ( Sending data, NoteCreated response ) ->
            case response of
                Ok _ ->
                    ( Generating { token = data.token }, generateFileName )

                Err error ->
                    ( Failing
                        { baseName = data.baseName
                        , content = data.content
                        , token = data.token
                        , httpError = error
                        }
                    , Cmd.none
                    )

        ( Sending _, _ ) ->
            ( model, Cmd.none )

        ( Failing _, _ ) ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


createNote : String -> String -> String -> Cmd Msg
createNote token baseName_ content =
    Http.request
        { method = "PUT"
        , headers =
            [ Http.header "Authorization" ("Bearer " ++ token)
            , Http.header "Accept" "application/vnd.github.v3+json"
            ]
        , url =
            ("https://api.github.com/repos/" ++ repo)
                ++ ("/contents/notes/" ++ baseName_ ++ ".md")
        , body =
            Http.stringBody "application/json"
                (Encode.encode 0 <|
                    Encode.object
                        [ ( "message", Encode.string ("Add note " ++ baseName_) )
                        , ( "content", Encode.string (Base64.encode content) )
                        ]
                )
        , expect = Http.expectWhatever NoteCreated
        , timeout = Nothing
        , tracker = Nothing
        }


generateFileName =
    Random.generate FileNameGenerated baseName


view : Model -> Html Msg
view model =
    case model of
        Generating _ ->
            text "Just let me do my thing..."

        Writing data ->
            viewEditor
                { sending = False
                , baseName = data.baseName
                , content = data.content
                , token = data.token
                }

        Sending data ->
            viewEditor
                { sending = True
                , baseName = data.baseName
                , content = data.content
                , token = data.token
                }

        Failing { httpError } ->
            text (Debug.toString httpError)


viewEditor data =
    let
        lineCount =
            data.content
                |> String.lines
                |> List.length
                |> (+) 1
    in
    Html.form
        [ Html.Events.onSubmit CreateNoteClicked
        , style "display" "flex"
        , style "flex-flow" "column nowrap"
        , style "max-width" "600px"
        , style "margin" "auto"
        , style "padding" "2rem 0 2rem"
        ]
        [ Html.h1 [] [ text "New Note" ]
        , Html.label []
            [ text "File: "
            , Html.input
                [ Html.Attributes.type_ "text"
                , Html.Attributes.value data.baseName
                , Html.Attributes.readonly True
                , Html.Events.onInput BaseNameChanged
                ]
                []
            , Html.span [] [ text ".md" ]
            ]
        , Html.label []
            [ text "Token: "
            , Html.input
                [ Html.Attributes.type_ "text"
                , Html.Attributes.value data.token
                , Html.Events.onInput TokenChanged
                ]
                []
            ]
        , Html.label [ style "display" "contents" ]
            [ Html.div [] [ text "Note: " ]
            , Html.textarea
                [ Html.Events.onInput ContentChanged
                , Html.Attributes.value data.content
                , Html.Attributes.disabled data.sending
                , Html.Attributes.rows (max 3 lineCount)
                , Html.Events.on "keydown"
                    (Decode.map2 Tuple.pair
                        Html.Events.keyCode
                        (Decode.field "ctrlKey" Decode.bool)
                        |> Decode.andThen
                            (\( keyCode, ctrlKey ) ->
                                if keyCode == 13 then
                                    Decode.succeed CreateNoteClicked

                                else
                                    Decode.fail ""
                            )
                    )
                ]
                []
            ]
        , text "\u{00A0}"
        , Html.button
            [ Html.Attributes.disabled data.sending
            , Html.Attributes.type_ "submit"
            ]
            [ text
                (if data.sending then
                    "Sending…"

                 else
                    "Create Note"
                )
            ]
        ]


baseName : Generator String
baseName =
    Random.list 8 letter
        |> Random.map String.fromList


letter : Generator Char
letter =
    Random.uniform '0' (String.toList "123456789abcdef")
