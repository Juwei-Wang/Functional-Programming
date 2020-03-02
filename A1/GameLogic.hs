{-# LANGUAGE OverloadedStrings, TemplateHaskell, FlexibleContexts #-}
module GameLogic where

import Lens.Micro.Platform
import Data.List (sort, delete)


type ApplyMove = Move -> GameState -> GameState

type AiMove = GameState -> Move

data MoveType = Human | AI AiMove

type Coord = (Int, Int)
type Move = [Coord]

data Status = Red | Black | GameOver 
  deriving (Show, Eq)


data GameState =
  GameState { _blackPieces :: [Coord]
            , _redPieces :: [Coord]
            , _blackKings :: [Coord]
            , _redKings :: [Coord]
            , _status :: Status
            , _message :: String}
              deriving (Show, Eq)

makeLenses ''GameState


initialGameState :: GameState
initialGameState =
  GameState { _blackPieces = blackInit
            , _redPieces = redInit
            , _blackKings = []
            , _redKings = []
            , _status = Red
            , _message = ""}

blackInit :: [Coord]
blackInit = [ (1,0), (3,0), (5,0), (7,0)
            , (0,1), (2,1), (4,1), (6,1)
            , (1,2), (3,2), (5,2), (7,2)]

redInit :: [Coord]
redInit = [ (0,7), (2,7), (4,7), (6,7)
          , (1,6), (3,6), (5,6), (7,6)
          , (0,5), (2,5), (4,5), (6,5)]

setMessage :: GameState -> GameState
setMessage s = case (s^.status) of
  Red -> set message
    "Red Turn." s
  Black -> set message
    "Black Turn." s
  _ -> s
applyMove :: Move -> GameState -> GameState
applyMove _  s = case s^.status of
  Red -> setMessage $ set status Black s
  Black -> setMessage $ set status Red s
  _ -> initialGameState

-- moves 

simple_moves :: GameState -> [Move]
simple_moves s = case s^.status of
    Red -> map (\(x,y) -> [x,y]) (sort (legalmovespieces ++ legalmoveskings)) 
          where
            newpieces        = map (\(x,y) -> (x+1, y-1)) redpieces ++ 
                               map (\(x,y) -> (x-1, y-1)) redpieces
            allmovespieces   = zip (redpieces ++ redpieces) newpieces
            legalmovespieces = filter (\(_, (x,y)) -> x >= 0 && x <= 7 &&  not ((x,y) `elem` allpieces)) allmovespieces
            newkings         = map (\(x,y) -> (x+1, y-1)) redkings ++ 
                               map (\(x,y) -> (x-1, y-1)) redkings ++
                               map (\(x,y) -> (x+1, y+1)) redkings ++ 
                               map (\(x,y) -> (x-1, y+1)) redkings        
            allmovekings     = zip (redkings ++ redkings ++ redkings ++ redkings) newkings
            legalmoveskings  = filter (\(_, (x,y)) -> x >= 0 && x <= 7 && y >= 0 && y <= 7 && not ((x,y) `elem` allpieces)) allmovekings
    Black -> map (\(x,y) -> [x,y]) (sort (legalmovespieces ++ legalmoveskings)) 
          where
            newpieces        = map (\(x,y) -> (x+1, y+1)) blackpieces ++ 
                               map (\(x,y) -> (x-1, y+1)) blackpieces
            allmovespieces   = zip (blackpieces ++ blackpieces) newpieces
            legalmovespieces = filter (\(_, (x,y)) -> x >= 0 && x <= 7 &&  not ((x,y) `elem` allpieces)) allmovespieces
            newkings         = map (\(x,y) -> (x+1, y-1)) blackkings ++ 
                               map (\(x,y) -> (x-1, y-1)) blackkings ++
                               map (\(x,y) -> (x+1, y+1)) blackkings ++ 
                               map (\(x,y) -> (x-1, y+1)) blackkings        
            allmovekings     = zip (blackkings ++ blackkings ++ blackkings ++ blackkings) newkings
            legalmoveskings  = filter (\(_, (x,y)) -> x >= 0 && x <= 7 && y >= 0 && y <= 7 &&  not ((x,y) `elem` allpieces)) allmovekings
    _ -> []
  where
    redpieces   = _redPieces s
    blackpieces = _blackPieces s
    redkings    = _redKings s
    blackkings  = _blackKings s
    allpieces   = redpieces ++ blackpieces ++ redkings ++ blackkings


jump_moves :: GameState -> [Move]
jump_moves s = case s^.status of
    Red   -> legalpiecesmoves ++ legalkingsmoves
      where
        allpiecesmoves   = concatMap (\x -> jump_pieces [(delete_piece s Red x, [x])] Red []) redpieces
        legalpiecesmoves = filter (\x -> length x > 1) allpiecesmoves
        allkingsmoves    = concatMap (\x -> jump_kings [(delete_piece s Red x, [x])] Red []) redkings
        legalkingsmoves  = filter (\x -> length x > 1) allkingsmoves
    Black -> legalpiecesmoves ++ legalkingsmoves
      where
        allpiecesmoves   = concatMap (\x -> jump_pieces [(delete_piece s Black x, [x])] Black []) blackpieces
        legalpiecesmoves = filter (\x -> length x > 1) allpiecesmoves
        allkingsmoves    = concatMap (\x -> jump_kings [(delete_piece s Black x, [x])] Black []) blackkings
        legalkingsmoves  = filter (\x -> length x > 1) allkingsmoves
    _     -> []
  where
    redpieces   = _redPieces s
    blackpieces = _blackPieces s
    redkings    = _redKings s
    blackkings  = _blackKings s
    allpieces   = redpieces ++ blackpieces ++ redkings ++ blackkings

moves :: GameState -> [Move]
moves s 
    | jumps == [] = simples
    | otherwise   = jumps
  where
    simples = simple_moves s 
    jumps = jump_moves s 

-- helper function 

jump_one_piece :: (GameState,Move) -> Status -> [(GameState,Move)]
jump_one_piece (s, (x,y):t) status = case status of 
  Red   | y == 0    -> jump_one_king (s, (x,y):t) status -- Crowning!
        | otherwise -> sAndmove1 ++ sAndmove2
          where
            sAndmove1 = if legal_jump s status (x,y) (x+2, y-2) then [(delete_piece s Black (x+1, y-1), (x+2, y-2):(x,y):t)] else []
            sAndmove2 = if legal_jump s status (x,y) (x-2, y-2) then [(delete_piece s Black (x-1, y-1), (x-2, y-2):(x,y):t)] else []
  Black | y == 7    -> jump_one_king (s, (x,y):t) status -- Crowning!
        | otherwise -> sAndmove1 ++ sAndmove2
          where
            sAndmove1 = if legal_jump s status (x,y) (x+2, y+2) then [(delete_piece s Red (x+1, y+1), (x+2, y+2):(x,y):t)] else []
            sAndmove2 = if legal_jump s status (x,y) (x-2, y+2) then [(delete_piece s Red (x-1, y+1), (x-2, y+2):(x,y):t)] else []
  _     -> []


jump_one_king :: (GameState, Move) -> Status -> [(GameState,Move)]
jump_one_king (s, (x,y):t) status = case status of 
  Red     -> sAndmove1 ++ sAndmove2 ++ sAndmove3 ++ sAndmove4
          where
            sAndmove1 = if legal_jump s status (x,y) (x+2, y-2) then [(delete_piece s Black (x+1, y-1), (x+2, y-2):(x,y):t)] else []
            sAndmove2 = if legal_jump s status (x,y) (x-2, y-2) then [(delete_piece s Black (x-1, y-1), (x-2, y-2):(x,y):t)] else []
            sAndmove3 = if legal_jump s status (x,y) (x+2, y+2) then [(delete_piece s Black (x+1, y+1), (x+2, y+2):(x,y):t)] else []
            sAndmove4 = if legal_jump s status (x,y) (x-2, y+2) then [(delete_piece s Black (x-1, y+1), (x-2, y+2):(x,y):t)] else []
  Black  -> sAndmove1 ++ sAndmove2 ++ sAndmove3 ++ sAndmove4
          where
            sAndmove1 = if legal_jump s status (x,y) (x+2, y-2) then [(delete_piece s Red (x+1, y-1), (x+2, y-2):(x,y):t)] else []
            sAndmove2 = if legal_jump s status (x,y) (x-2, y-2) then [(delete_piece s Red (x-1, y-1), (x-2, y-2):(x,y):t)] else []
            sAndmove3 = if legal_jump s status (x,y) (x+2, y+2) then [(delete_piece s Red (x+1, y+1), (x+2, y+2):(x,y):t)] else []
            sAndmove4 = if legal_jump s status (x,y) (x-2, y+2) then [(delete_piece s Red (x-1, y+1), (x-2, y+2):(x,y):t)] else []
  _     -> []

legal_jump :: GameState -> Status -> Coord -> Coord -> Bool
legal_jump s status (x,y) (nx,ny) = x >= 0 && x <= 7 && y >= 0 && nx >= 0 && ny <= 7 && y <= 7 && ny >= 0 && ny <= 7 && 
  case status of 
    Red   -> inter `elem` blacks && not ((nx,ny) `elem` allpieces)
    Black -> inter `elem` reds && not ((nx,ny) `elem` allpieces)
  where
    inter       = ((x + nx) `div` 2, (y + ny) `div` 2)
    redpieces   = _redPieces s
    blackpieces = _blackPieces s
    redkings    = _redKings s
    blackkings  = _blackKings s
    reds        = redpieces ++ redkings
    blacks      = blackpieces ++ blackkings
    allpieces   = redpieces ++ blackpieces ++ redkings ++ blackkings

jump_pieces :: [(GameState, Move)] -> Status -> [Move] -> [Move]
jump_pieces [] _ acc = acc
jump_pieces (x:xs) status acc 
      | nexts == []  = jump_pieces xs status (reverse (snd x) : acc) 
      | otherwise    = jump_pieces (nexts ++ xs) status acc 
   where
    nexts = jump_one_piece x status 

jump_kings :: [(GameState, Move)] -> Status -> [Move] -> [Move]
jump_kings [] _ acc = acc
jump_kings (x:xs) status acc 
      | nexts == []  = jump_kings xs status (reverse (snd x) : acc) 
      | otherwise    = jump_kings (nexts ++ xs) status acc 
   where
    nexts = jump_one_king x status 

delete_piece :: GameState -> Status -> Coord -> GameState
delete_piece (GameState bp rp bk rk st m) status x = case status of 
    Red   -> GameState bp (delete x rp) bk (delete x rk) st m
    Black -> GameState (delete x bp) rp (delete x bk) rk st m
    _     -> error ""