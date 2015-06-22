{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Hakyll.Web.Feed
import           Hakyll.Web.Tags
import qualified Data.Set as S
import           Text.Pandoc.Options
import           Text.Highlighting.Pygments (toHtml)


feedConfig :: FeedConfiguration
feedConfig = FeedConfiguration { feedTitle = "austinschwartz.com"
                               , feedDescription = "Austin Schwartz"
                               , feedAuthorName = "Austin Schwartz"
                               , feedRoot = "http://www.austinschwartz.com"
                               , feedAuthorEmail = "schwar12@purdue.edu"
                               }

pandocMathCompiler :: Compiler (Item String)
pandocMathCompiler =
    let mathExtensions = [Ext_tex_math_dollars, Ext_tex_math_double_backslash, Ext_latex_macros]
        defaultExtensions = writerExtensions defaultHakyllWriterOptions
        newExtensions = foldr S.insert defaultExtensions mathExtensions
        writerOptions = defaultHakyllWriterOptions {
                writerExtensions = newExtensions,
                writerHTMLMathMethod = MathJax ""
                }
    in pandocCompilerWith defaultHakyllReaderOptions writerOptions


blockToHtml :: Block -> IO Block
blockToHtml x@(CodeBlock attr _) | attr == nullAttr = return x
blockToHtml x@(CodeBlock (_,[],_) _) = return x
blockToHtml (CodeBlock (_,language:_,_) text) = do
  colored <- toHtml text language
  return (RawBlock (Format "html") colored)
blockToHtml x = return x

codeBlocksToHtml :: Pandoc -> IO Pandoc
codeBlocksToHtml = walkM blockToHtml

main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*.css" $ do
        route   idRoute
        compile compressCssCompiler

    match "css/*.scss" $ do
        route   $ setExtension "css"
        compile $ getResourceString 
          >>= withItemBody (unixFilter "sass" ["-s", "--scss"]) 
          >>= return . fmap compressCss

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocMathCompiler
            >>= loadAndApplyTemplate "partials/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Home"                `mappend`
                    defaultContext
            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "gpg.md" $ do
        route $ setExtension "html"
        compile $ pandocMathCompiler
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    match "partials/*"  $ compile templateCompiler
    match "templates/*" $ compile templateCompiler

--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext
