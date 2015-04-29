{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE KindSignatures      #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}
{-# LANGUAGE GADTs               #-}

-- |
-- Types for working with integers modulo some constant.
-- 
-- @'Mod'@ and its synonym @'/'@ let you wrap arbitrary numeric types
-- in a modulus. To work with integers (mod 7) backed by @Integer@,
-- you could write:
-- 
-- > Integer `Mod` 7
-- > Integer/7
-- > ℤ/7
-- 
-- (The last is a synonym for @Integer@ provided by this library. In
-- Emacs, you can use the TeX input mode to type it with @\\Bbb{Z}@.)
-- 
-- The usual numeric typeclasses are defined for these types. You can
-- always extrac the underlying value with @'unMod'@.
--
-- Here is a quick example:
-- 
-- > *Data.Modular> (10 :: ℤ/7) * (11 :: ℤ/7)
-- > 5
-- 
-- It also works correctly with negative numeric literals:
-- 
-- > *Data.Modular> (-10 :: ℤ/7) * (11 :: ℤ/7)
-- > 2
--
-- To us type level numeric literals you need to enable the
-- @DataKinds@ extension and to use infix syntax for @Mod@ or the @/@
-- synonym, you need @TypeOperators@.

module Data.Modular (unMod, toMod, toMod', Mod, inv, (/)(), ℤ, modVal, SomeMod, someModVal) where

import           Control.Arrow (first)

import           Data.Proxy    (Proxy (..))
import           Data.Ratio    ((%))

import           GHC.TypeLits

-- | The actual type, wrapping an underlying @Integeral@ type @i@ in a
-- newtype annotated with the bound.
newtype i `Mod` (n :: Nat) = Mod i deriving (Eq, Ord)

-- | Extract the underlying integral value from a modular type.
unMod :: i `Mod` n -> i
unMod (Mod i) = i

-- | A synonym for @Mod@, inspired by the ℤ/n syntax from mathematics.
type (/) = Mod

-- | A synonym for Integer, also inspired by the ℤ/n syntax.
type ℤ   = Integer

-- | Returns the bound of the modular type in the type itself. This
-- breaks the invariant of the type, so it shouldn't be used outside
-- this module.
_bound :: forall n i. (Integral i, KnownNat n) => i `Mod` n
_bound = Mod . fromInteger $ natVal (Proxy :: Proxy n)
                            
-- | Wraps the underlying type into the modular type, wrapping as
-- appropriate.
toMod :: forall n i. (Integral i, KnownNat n) => i -> i `Mod` n
toMod i = Mod $ i `mod` unMod (_bound :: i `Mod` n)

-- | Wraps an integral number to a mod, converting between integral
-- types.
toMod' :: forall n i j. (Integral i, Integral j, KnownNat n) => i -> j `Mod` n
toMod' i = toMod . fromIntegral $ i `mod` (fromInteger $ natVal (Proxy :: Proxy n))

instance Show i => Show (i `Mod` n) where show (Mod i) = show i
instance (Read i, Integral i, KnownNat n) => Read (i `Mod` n)
  where readsPrec prec = map (first toMod) . readsPrec prec

instance (Integral i, KnownNat n) => Num (i `Mod` n) where
  fromInteger = toMod . fromInteger

  Mod i₁ + Mod i₂ = toMod $ i₁ + i₂
  Mod i₁ * Mod i₂ = toMod $ i₁ * i₂

  abs    (Mod i) = toMod $ abs i
  signum (Mod i) = toMod $ signum i
  negate (Mod i) = toMod $ negate i

instance (Integral i, KnownNat n) => Enum (i `Mod` n) where
  toEnum = fromInteger . toInteger
  fromEnum = fromInteger . toInteger . unMod

  enumFrom     x   = enumFromTo     x maxBound
  enumFromThen x y = enumFromThenTo x y bound
    where
      bound | fromEnum y >= fromEnum x = maxBound
            | otherwise               = minBound

instance (Integral i, KnownNat n) => Bounded (i `Mod` n) where
  maxBound = pred _bound
  minBound = 0

instance (Integral i, KnownNat n) => Real (i `Mod` n) where
  toRational (Mod i) = toInteger i % 1

-- | Integer division uses modular inverse @'inv'@,
-- so it is possible to divide only by numbers coprime to @n@
-- and the remainder is always @0@.
instance (Integral i, KnownNat n) => Integral (i `Mod` n) where
  toInteger (Mod i) = toInteger i
  i₁ `quotRem` i₂ = (i₁ * inv i₂, 0)

-- | The modular inverse.
-- Note that only numbers coprime to @n@ have an inverse modulo @n@.
inv :: forall n i. (KnownNat n, Integral i) => Mod i n -> Mod i n
inv k = toMod . snd . inv' (fromInteger (natVal (Proxy :: Proxy n))) . unMod $ k
  where
    -- these are only used for error message
    modulus = show $ natVal (Proxy :: Proxy n)
    divisor = show (toInteger k)

    -- backwards Euclidean algorithm
    inv' _ 0 = error ("divide by " ++ divisor ++ " (mod " ++ modulus ++ "), non-coprime to modulus")
    inv' _ 1 = (0, 1)
    inv' n x = (r', q' - r' * q)
      where
        (q,  r)  = n `quotRem` x
        (q', r') = inv' x r

-- | This type represents a modular number with unknown bound.
data SomeMod i where
  SomeMod :: forall i (n :: Nat). KnownNat n => Mod i n -> SomeMod i

instance Show i => Show (SomeMod i) where
  showsPrec p (SomeMod x) = showsPrec p x

-- | Convert an integral number @i@ into a @'Mod'@ value given
-- modular bound @n@ at type level.
modVal :: forall i proxy n. (Integral i, KnownNat n) => i -> proxy n -> Mod i n
modVal i _ = toMod i

-- | Convert an integral number @i@ into an unknown @'Mod'@ value.
someModVal :: Integral i => i -> Integer -> Maybe (SomeMod i)
someModVal i n =
  case someNatVal n of
    Nothing -> Nothing
    Just (SomeNat proxy) -> Just (SomeMod (modVal i proxy))

