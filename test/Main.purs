module Test.Main where

import Prelude

import Control.Monad.Eff (Eff())
import Control.Monad.Eff.Console
import Data.Maybe
import Data.Monoid.Additive
import Data.Foldable
import Data.Traversable
import Data.Bifoldable
import Data.Bifunctor
import Data.Bitraversable
import Test.Assert

foreign import arrayFrom1UpTo :: Int -> Array Int

main = do
  log "Test foldableArray instance"
  testFoldableArrayWith 20

  log "Test foldableArray instance is stack safe"
  testFoldableArrayWith 20000

  log "Test foldMapDefaultL"
  testFoldableFoldMapDefaultL 20

  log "Test foldMapDefaultR"
  testFoldableFoldMapDefaultR 20

  log "Test foldlDefault"
  testFoldableFoldlDefault 20

  log "Test foldrDefault"
  testFoldableFoldlDefault 20

  log "Test traversableArray instance"
  testTraversableArrayWith 20

  log "Test traversableArray instance is stack safe"
  testTraversableArrayWith 20000

  log "Test traverseDefault"
  testTraverseDefault 20

  log "Test sequenceDefault"
  testSequenceDefault 20

  log "Test Bifoldable on `inclusive or`"
  testBifoldableIOrWith 10 100 42

  log "Test Bitraversable on `inclusive or`"
  testBitraversableIOr

  log "All done!"


testFoldableFWith :: forall f e. (Foldable f, Eq (f Int)) =>
                     (Int -> f Int) -> Int -> Eff (assert :: ASSERT | e) Unit
testFoldableFWith f n = do
  let dat = f n
  let expectedSum = (n / 2) * (n + 1)

  assert $ foldr (+) 0 dat == expectedSum
  assert $ foldl (+) 0 dat == expectedSum
  assert $ foldMap Additive dat == Additive expectedSum

testFoldableArrayWith = testFoldableFWith arrayFrom1UpTo


testTraversableFWith :: forall f e. (Traversable f, Eq (f Int)) =>
                        (Int -> f Int) -> Int -> Eff (assert :: ASSERT | e) Unit
testTraversableFWith f n = do
  let dat = f n

  assert $ traverse Just dat == Just dat
  assert $ traverse return dat == [dat]
  assert $ traverse (\x -> if x < 10 then Just x else Nothing) dat == Nothing
  assert $ sequence (map Just dat) == traverse Just dat

testTraversableArrayWith = testTraversableFWith arrayFrom1UpTo


-- structures for testing default `Foldable` implementations

newtype FoldMapDefaultL a = FML (Array a)
newtype FoldMapDefaultR a = FMR (Array a)
newtype FoldlDefault    a = FLD (Array a)
newtype FoldrDefault    a = FRD (Array a)

instance eqFML :: (Eq a) => Eq (FoldMapDefaultL a) where eq (FML l) (FML r) = l == r
instance eqFMR :: (Eq a) => Eq (FoldMapDefaultR a) where eq (FMR l) (FMR r) = l == r
instance eqFLD :: (Eq a) => Eq (FoldlDefault a)    where eq (FLD l) (FLD r) = l == r
instance eqFRD :: (Eq a) => Eq (FoldrDefault a)    where eq (FRD l) (FRD r) = l == r

-- implemented `foldl` and `foldr`, but default `foldMap` using `foldl`
instance foldableFML :: Foldable FoldMapDefaultL where
  foldMap f         = foldMapDefaultL f
  foldl f u (FML a) = foldl f u a
  foldr f u (FML a) = foldr f u a

-- implemented `foldl` and `foldr`, but default `foldMap`, using `foldr`
instance foldableFMR :: Foldable FoldMapDefaultR where
  foldMap f         = foldMapDefaultR f
  foldl f u (FMR a) = foldl f u a
  foldr f u (FMR a) = foldr f u a

-- implemented `foldMap` and `foldr`, but default `foldMap`
instance foldableDFL :: Foldable FoldlDefault where
  foldMap f (FLD a) = foldMap f a
  foldl f u         = foldlDefault f u
  foldr f u (FLD a) = foldr f u a

-- implemented `foldMap` and `foldl`, but default `foldr`
instance foldableDFR :: Foldable FoldrDefault where
  foldMap f (FRD a) = foldMap f a
  foldl f u (FRD a) = foldl f u a
  foldr f u         = foldrDefault f u

testFoldableFoldMapDefaultL = testFoldableFWith (FML <<< arrayFrom1UpTo)
testFoldableFoldMapDefaultR = testFoldableFWith (FMR <<< arrayFrom1UpTo)
testFoldableFoldlDefault    = testFoldableFWith (FLD <<< arrayFrom1UpTo)
testFoldableFoldrDefault    = testFoldableFWith (FRD <<< arrayFrom1UpTo)


-- structures for testing default `Traversable` implementations

newtype TraverseDefault a = TD (Array a)
newtype SequenceDefault a = SD (Array a)

instance eqTD :: (Eq a) => Eq (TraverseDefault a) where eq (TD l) (TD r) = l == r
instance eqSD :: (Eq a) => Eq (SequenceDefault a) where eq (SD l) (SD r) = l == r

instance functorTD :: Functor TraverseDefault where map f (TD a) = TD (map f a)
instance functorSD :: Functor SequenceDefault where map f (SD a) = SD (map f a)

instance foldableTD :: Foldable TraverseDefault where
  foldMap f (TD a) = foldMap f a
  foldr f u (TD a) = foldr f u a
  foldl f u (TD a) = foldl f u a

instance foldableSD :: Foldable SequenceDefault where
  foldMap f (SD a) = foldMap f a
  foldr f u (SD a) = foldr f u a
  foldl f u (SD a) = foldl f u a

instance traversableTD :: Traversable TraverseDefault where
  traverse f      = traverseDefault f
  sequence (TD a) = map TD (sequence a)

instance traversableSD :: Traversable SequenceDefault where
  traverse f (SD a) = map SD (traverse f a)
  sequence m        = sequenceDefault m

testTraverseDefault = testTraversableFWith (TD <<< arrayFrom1UpTo)
testSequenceDefault = testTraversableFWith (SD <<< arrayFrom1UpTo)


-- structure for testing bifoldable, picked `inclusive or` as it has both products and sums

data IOr l r = Both l r | Fst l | Snd r

instance eqIOr :: (Eq l, Eq r) => Eq (IOr l r) where
  eq (Both lFst lSnd) (Both rFst rSnd) = (lFst == rFst) && (lSnd == rSnd)
  eq (Fst l)          (Fst r)          = l == r
  eq (Snd l)          (Snd r)          = l == r
  eq _                _                = false

instance bifoldableIOr :: Bifoldable IOr where
  bifoldr l r u (Both fst snd) = l fst (r snd u)
  bifoldr l r u (Fst fst)      = l fst u
  bifoldr l r u (Snd snd)      = r snd u

  bifoldl l r u (Both fst snd) = r (l u fst) snd
  bifoldl l r u (Fst fst)      = l u fst
  bifoldl l r u (Snd snd)      = r u snd

  bifoldMap l r (Both fst snd) = l fst <> r snd
  bifoldMap l r (Fst fst)      = l fst
  bifoldMap l r (Snd snd)      = r snd

instance bifunctorIOr :: Bifunctor IOr where
  bimap f g (Both fst snd) = Both (f fst) (g snd)
  bimap f g (Fst fst)      = Fst (f fst)
  bimap f g (Snd snd)      = Snd (g snd)

instance bitraversableIOr :: Bitraversable IOr where
  bitraverse f g (Both fst snd) = Both <$> f fst <*> g snd
  bitraverse f g (Fst fst)      = Fst <$> f fst
  bitraverse f g (Snd snd)      = Snd <$> g snd

  bisequence (Both fst snd) = Both <$> fst <*> snd
  bisequence (Fst fst)      = Fst <$> fst
  bisequence (Snd snd)      = Snd <$> snd

testBifoldableIOrWith :: forall e. Int -> Int -> Int -> Eff (assert :: ASSERT | e) Unit
testBifoldableIOrWith fst snd u = do
  assert $ bifoldr (+) (*) u (Both fst snd) == fst + (snd * u)
  assert $ bifoldr (+) (*) u (Fst fst)      == fst + u
  assert $ bifoldr (+) (*) u (Snd snd)      == snd * u

  assert $ bifoldl (+) (*) u (Both fst snd) == (u + fst) * snd
  assert $ bifoldl (+) (*) u (Fst fst)      == u + fst
  assert $ bifoldl (+) (*) u (Snd snd)      == u * snd

  assert $ bifoldMap Additive Additive (Both fst snd) == Additive (fst + snd)
  assert $ bifoldMap Additive Additive (Fst fst)      == Additive fst
  assert $ bifoldMap Additive Additive (Snd snd)      == Additive snd

testBitraversableIOr :: forall e. Eff (assert :: ASSERT | e) Unit
testBitraversableIOr = do
  assert $ bisequence (Both (Just true) (Just false)) == Just (Both true false)
  assert $ bisequence (Fst (Just true))               == Just (Fst true  :: IOr Boolean Boolean)
  assert $ bisequence (Snd (Just false))              == Just (Snd false :: IOr Boolean Boolean)
  assert $ bitraverse Just Just (Both true false)     == Just (Both true false)
  assert $ bitraverse Just Just (Fst true)            == Just (Fst true  :: IOr Boolean Boolean)
  assert $ bitraverse Just Just (Snd false)           == Just (Snd false :: IOr Boolean Boolean)

