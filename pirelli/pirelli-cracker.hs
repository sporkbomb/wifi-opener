--module Main( main ) where

import System( getArgs )
import Numeric
import qualified Crypto.Hash.SHA256 as SHA
import qualified Data.ByteString as B
import Data.Word

splitEvery :: Int -> [a] -> [[a]]
splitEvery _ [] = []
splitEvery n xs = (take n xs) : (splitEvery n (drop n xs))

fromHexString :: [Char] -> B.ByteString
fromHexString str
   | length (str) `mod` 2 == 0 =  B.concat $ map (B.singleton . unpackHex . readHex) $ splitEvery 2 str
   | otherwise 	               = error "You're missing a nibble."

unpackHex :: (Integral a) => [(a, String)] -> Word8
unpackHex ins = fromIntegral . fst . head $ ins

genSSID :: B.ByteString -> [Char]
genSSID mac = concat $ map (flip (showHex) "") $ take 3 . drop 3 $ B.unpack mac

seededHash :: B.ByteString -> B.ByteString -> B.ByteString
seededHash key seed = SHA.finalize $ flip (SHA.update) key $ flip (SHA.update) seed $ SHA.init

genPSK :: B.ByteString -> [Char]
genPSK mac = map (\x -> lookup!!((fromIntegral x) `mod` lookuplength)) $ take 12 $ B.unpack $ seededHash mac seed 
             where seed = fromHexString "54454F74656CB6D986968D3445D23B15CAAF128402AC560005CE2075943FDCE8" 
                   lookup = ['0'..'9'] ++ ['A'..'Z'] ++ ['a'..'z']
		   lookuplength = length lookup

toBSSID :: B.ByteString -> B.ByteString
toBSSID mac = B.pack $ left ++ (bssidelem : right)
              where unpacked = B.unpack mac
	            left = take 5 unpacked
	            right = drop 6 unpacked
		    bssidelem = (unpacked!!5)-5

main = do
       (macstr:_) <- getArgs
       let mac = fromHexString macstr
           bssid = toBSSID mac
--       putStrLn $ "Input: " ++ (show $ mac)
       putStrLn $ "From MAC: PBS-" ++ (genSSID mac) ++ " | " ++ (genPSK mac)
       putStrLn $ "From BSSID: PBS-" ++ (genSSID bssid) ++ " | " ++ (genPSK bssid)
