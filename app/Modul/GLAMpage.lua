-- ## Modul:GLAMpage is a Lua Libary with Service-Functions for the GLAMpage Template ##
-- Please use this module via Template:GLAMpage only!
-- Modul:Tutorials requires a customisable config.json, passed via the parameter config to each function call
-- The Default is Template:GLAMpage/config.json

-- Helper Functions

-- Local functions and vars

local configData, templateData, rootNode, rootNodes
local currentTitle, currentNode, refNode, lastNode, nextNode 
local pagesById = {}
local rootNodesByLang = {}
local isAllPage
local currentPageNo = 0
local totalPageNo = 0
local isLastNode = false
local showHidden = false
local inited = false

function init(configPage)
    if inited then return end
    inited = true

    -- Functions

    local previousNode

    function initNode(node, i, parentNode)
        node.index = i
        node.childCount = 0

        if  node.page then
            node.title = mw.title.new(node.page)
            node.isCurrentPage = mw.title.equals( currentTitle, node.title )

            if not node.isCurrentPage and node.pageAliases then  
                local ai, a, at              
                for ai, a in pairs( node.pageAliases ) do
                    if mw.title.equals( currentTitle, mw.title.new(a) ) then
                        node.isCurrentPage = true
                    end
                end
            end

            node.containsCurrentPage = node.isCurrentPage
        else
            node.isLabel = true
        end

        --node.isAllPage = false
        node.isLastNode = false
        
        if parentNode then
            node.parent = parentNode
            node.root = parentNode.root
        else
            node.root = node
        end

        if not node.isCurrentPage and node.all then
            node.allTitle = mw.title.new(node.all)
            if mw.title.equals( currentTitle,  node.allTitle ) then 
                node.isCurrentPage = true
                node.isAllPage = true
            end
        end

        if previousNode then
            previousNode.nextNode = node
            node.lastNode = previousNode
            --[[ -- Funktioniert noch nicht
            if previousNode.parent == node.parent or previousNode ~= node.parent  then
            else
                previousNode.isLastNode = true
            end
            ]]--
        end
        previousNode = node

        if node.children then 
            local newChildrenArray = {}

            for childIndex, childNode in pairs( node.children ) do

                initNode(childNode, childIndex, node)

                if childNode.containsCurrentPage then
                    node.containsCurrentPage = true
                end

                if not (childNode.hidden and not childNode.containsCurrentPage) or showHidden then
                    node.childCount = node.childCount + 1
                    newChildrenArray[node.childCount] = childNode
                end
            end
            node.children = newChildrenArray
        end        

        node.refNode = node;
        if parentNode then
            if node.childCount == 0 then
                node.refNode = node.parent;
            end
        end   
        
        if node.isCurrentPage then
            currentNode = node
        end

        if node.refNode == node then
            node.isRefNode = true
        end

        if node.id then            
            pagesById[node.id] = pagesById[node.id] or {}
            pagesById[node.id][node.root.lang] = node 
        end

        return node;
    end
    
    function prepareNodeHtml(node, i, parentNode)

        node.innerHtml = 
            node.isLabel and templateData.threadNaviLabel or
            node.isCurrentPage and templateData.threadNaviItemActive or 
            templateData.threadNaviItem
        
        if node.page then
            node.innerHtml = node.innerHtml:gsub("§§page§§", (isAllPage and '#' or '') .. node.page)        
        end
        
        node.innerHtml = node.innerHtml:gsub("§§name§§", node.name)

        node.childHtml = ''        
        if node.children then 
            for childIndex, childNode in pairs( node.children ) do
                prepareNodeHtml(childNode, childIndex, node)
            end
        end

        local isActive = node.isCurrentPage or node.containsCurrentPage
        local classes = (isActive and ' active' or '') .. (node.isLabel and ' label' or '')

        node.childHtml = (node.childHtml == '') and '' or ('<ul>' .. node.childHtml .. '</ul>')
        node.outerHtml = '<li' .. (classes and ' class="'.. classes ..'"' or '') ..  '>' .. node.innerHtml .. node.childHtml .. '</li>'

        if parentNode and (node.containsCurrentPage or (not node.hidden))  then
            parentNode.childHtml = parentNode.childHtml .. node.outerHtml
        end        

        return node;
    end;


    --mw.log('Lua Init')


    -- Processing

    currentTitle = mw.title.getCurrentTitle()       
    if not configPage then configPage = 'Template:GLAMpage/config.json' end
    configData = mw.text.jsonDecode( mw.title.new(configPage):getContent() )

    rootNodes = configData.structure
    templateData = configData.templates

    local refLang, firstRoot

    for rootIndex, rootNode in pairs( rootNodes ) do

        if not firstRoot then firstRoot = rootNode end

        refNode = rootNode
        refLang = rootNode.lang

        if refLang then rootNodesByLang[refLang] = rootNode end
            
        initNode(rootNode, 0, false)

    end

    if not currentNode then
        currentNode = firstRoot;
    end

    if currentNode then
        refNode = currentNode.refNode
        totalPageNo = refNode.childCount
        currentPageNo = currentNode.index
        isLastNode = currentNode.isLastNode
        isAllPage = currentNode.isAllPage
        nextNode = currentNode.nextNode
        lastNode = currentNode.lastNode
    end
    
    prepareNodeHtml(currentNode.root, 0)
end

function getPageContent( node, frame )
    if not node then 
        return ''
    end     
    local source, html
    source = node.title:getContent()
    html = frame:preprocess( tostring( mw.html.create( "div" ):wikitext( source ) ) )

    return '<h2>' .. node.name .. '</h2>' .. html
end

function getNodeByTitle(title, node)
    local childNode, childIndex, foundNode, isBase

    if not title then 
        return currentNode
    end

    if not node then 
        node = rootNode 
        isBase = true
    end

    if mw.title.equals( title, node.title ) then
        return node
    else
        if node.children then                 
            for childIndex, childNode in pairs( node.children ) do
                foundNode = getNodeByTitle(title, childNode)
                if foundNode then 
                    return foundNode
                end
            end
        end
        if isBase then 
            return currentNode
        else 
            return false
        end
    end
end

-- Public Interface

local p = {} 

function p.navIndex(frame)
    mw.log('Lua navIndex ', frame)

    init( frame.args[config] );
    local node = getNodeByTitle(frame.args[title])
    return node.refNode.childHtml
end

function p.navi(frame)    
    mw.log('Lua navWidget ', frame)
    init( frame.args[config] );

    local node = currentNode
    local widgetHtml = templateData.widget:gsub("§§rootPage§§",node.root.page):gsub("§§threadNavi§§", node.root.innerHtml .. node.root.childHtml ) --:gsub("§§pagina§§", pagina )

    return widgetHtml
end

function p.home(frame)
    mw.log('Lua home ', frame)
    init( frame.args[config] );

    return currentNode.root.page
end

function p.homeLink(frame)
    mw.log('Lua home ', frame)
    init( frame.args[config] );

    local node = currentNode
    local homeHtml = templateData.homeLink:gsub("§§page§§",node.root.page)

    return homeHtml
end

return p