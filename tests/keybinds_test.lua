local Keys = require("src.input.keybinds")

return {
    {
        name = "every action has a default key",
        run = function()
            Keys.parse(nil)
            for _, action in ipairs(Keys.actions) do
                assert(Keys.keys(action.id)[1], action.id)
            end
            assert(Keys.is("dash", "space") and Keys.is("dash", "lshift") and not Keys.is("dash", "r"))
        end
    },
    {
        name = "bindings survive a save and load round trip",
        run = function()
            Keys.parse(nil)
            local saved = Keys.save
            Keys.save = function() end
            Keys.set("reload", 1, "t")
            Keys.set("quiet", 2, nil)
            local text = Keys.serialize()
            Keys.parse(text)
            assert(Keys.is("reload", "t") and not Keys.is("reload", "r"))
            assert(Keys.keys("quiet")[2] == nil and Keys.is("quiet", "c"))
            Keys.save = saved
        end
    },
    {
        name = "binding a key that is already used moves it",
        run = function()
            Keys.parse(nil)
            local saved = Keys.save
            Keys.save = function() end
            local moved = Keys.set("reload", 1, "g")
            assert(moved == "throw", "the throw key moves")
            assert(Keys.is("reload", "g") and not Keys.is("throw", "g"))
            Keys.save = saved
        end
    },
    {
        name = "escape can't be bound and broken files fall back to defaults",
        run = function()
            Keys.parse("reload=escape,\nnonsense\nforward=,")
            local saved = Keys.save
            Keys.save = function() end
            Keys.set("help", 1, "escape")
            assert(Keys.is("help", "h"), "escape is refused")
            assert(Keys.keys("forward")[1] == nil, "an emptied slot stays empty")
            assert(not Keys.is("reload", "escape"), "escape from a file is ignored")
            Keys.parse(nil)
            Keys.save = saved
        end
    }
}
