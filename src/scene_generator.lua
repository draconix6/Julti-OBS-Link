obs = obslua

function request_generate_stream_scenes()
    gen_stream_scenes_requested = true
end

function generate_stream_scenes()
    local julti_source = get_source("Julti")

    if julti_source == nil then
        obs.script_log(200, "You must press the regular \"Generate Scenes\" button first!")
        return
    end

    if not scene_exists("Playing") then
        create_scene("Playing")
        obs.obs_scene_add(get_scene("Playing"), julti_source)
    end
    if not scene_exists("Walling") then
        create_scene("Walling")
        local scene = get_scene("Walling")

        obs.obs_scene_add(scene, julti_source)

        local settings = obs.obs_data_create_from_json(
            '{"file":"' .. julti_dir ..
            'resets.txt","font":{"face":"Arial","flags":0,"size":48,"style":"Regular"},"opacity":50,"read_from_file":true}'
        )
        local counter_source = obs.obs_source_create("text_gdiplus", "Reset Counter", settings, nil)
        obs.obs_scene_add(scene, counter_source)
        release_source(counter_source)
        obs.obs_data_release(settings)
    end

    release_source(julti_source)
end

function request_generate_scenes()
    gen_scenes_requested = true
end

function generate_scenes()
    local already_existing = {}
    local found_ae = false

    local out = get_state_file_string()
    if (out == nil) or not (string.find(out, ";")) then
        obs.script_log(200, "------------------------------")
        obs.script_log(100, "Julti has not yet been set up! Please setup Julti first!")
        return
    end
    local instance_count = (#(split_string(out, ";"))) - 1

    if not scene_exists("Lock Display") then
        _setup_lock_scene()
    else
        table.insert(already_existing, "Lock Display")
        found_ae = true
    end

    -- Check if current scene is on Julti, which messes things up
    local current_scene_source = obs.obs_frontend_get_current_scene()
    local current_scene_name = obs.obs_source_get_name(current_scene_source)
    release_source(current_scene_source)
    if current_scene_name == "Julti" then
        switch_to_scene("Lock Display")
        gen_scenes_requested = true
        return
    end

    if not scene_exists("Dirt Cover Display") then
        _setup_cover_scene()
    else
        table.insert(already_existing, "Dirt Cover Display")
        found_ae = true
    end

    if not scene_exists("Sound") then
        _setup_sound_scene()
    else
        table.insert(already_existing, "Sound")
        found_ae = true
    end

    _ensure_empty_important_scenes()

    _setup_julti_scene()

    _setup_verification_scene()


    -- Reset variables to have loop update stuff automatically
    last_state_text = ""
    last_scene_name = ""

    if found_ae then
        -- Report already existing scenes

        obs.script_log(200, "------------------------------")
        obs.script_log(200, "The following scenes already exist:")

        for _, v in pairs(already_existing) do
            obs.script_log(200, "- " .. v)
        end

        obs.script_log(200, "If you want to recreate these scenes,")
        obs.script_log(200, "delete them first before pressing Generate Scenes.")
    end
end

function _fix_bad_names(instance_count)
    for i = 1, instance_count, 1 do
        local source = get_source("Minecraft Capture " .. i)
        if source == nil then
            obs.script_log(200, "Fixing " .. i)
            source = get_source("Minecraft Capture " .. i .. " 2")
            local data = obs.obs_source_get_settings(source)
            local a = obs.obs_data_get_json(data)
            obs.script_log(200, "stuff " .. a)
            obs.obs_data_set_string(data, "name", "Minecraft Capture " .. i)
            obs.obs_data_release(data)
        end
        release_source(source)
    end
end

function _ensure_empty_important_scenes()
    for instance_num = 1, 100 do
        -- Empty square groups
        local group_scene = get_group_as_scene("Square " .. instance_num)
        if (group_scene ~= nil) then
            local items = obs.obs_scene_enum_items(group_scene)
            for _, item in ipairs(items) do
                obs.obs_sceneitem_remove(item)
            end
            obs.sceneitem_list_release(items)
        end

        -- Empty instance groups
        local group_scene = get_group_as_scene("Instance " .. instance_num)
        if (group_scene ~= nil) then
            local items = obs.obs_scene_enum_items(group_scene)
            for _, item in ipairs(items) do
                obs.obs_sceneitem_remove(item)
            end
            obs.sceneitem_list_release(items)
        end

        -- Delete sources
        delete_source("Minecraft Capture " .. instance_num)
        delete_source("Verification Capture " .. instance_num)
        delete_source("Minecraft Audio " .. instance_num)
        delete_source("Instance " .. instance_num)
        delete_source("Square " .. instance_num)
    end
    -- Empty sound group
    local group_scene = get_group_as_scene("Minecraft Audio")
    if (group_scene ~= nil) then
        local items = obs.obs_scene_enum_items(group_scene)
        for _, item in ipairs(items) do
            obs.obs_sceneitem_remove(item)
        end
        obs.sceneitem_list_release(items)
    end
    -- Empty Verification scene
    if scene_exists("Verification") then
        obs.script_log(200, "------------------------------")
        obs.script_log(200, "Verification scene already existed,")
        obs.script_log(200, "all sources will be replaced.")
        local scene = get_scene("Verification")
        local items = obs.obs_scene_enum_items(scene)
        for _, item in ipairs(items) do
            obs.obs_sceneitem_remove(item)
        end
        obs.sceneitem_list_release(items)
    else
        create_scene("Verification")
    end
    -- Empty Julti scene
    if scene_exists("Julti") then
        obs.script_log(200, "------------------------------")
        obs.script_log(200, "Julti scene already existed,")
        obs.script_log(200, "all sources will be replaced.")
        local scene = get_scene("Julti")
        local items = obs.obs_scene_enum_items(scene)
        for _, item in ipairs(items) do
            obs.obs_sceneitem_remove(item)
        end
        obs.sceneitem_list_release(items)
    else
        create_scene("Julti")
    end
end

function _setup_cover_scene()
    create_scene("Dirt Cover Display")
    local scene = get_scene("Dirt Cover Display")

    local cover_data = obs.obs_data_create_from_json('{"file":"' .. julti_dir .. 'dirtcover.png' .. '"}')
    local cover_source = obs.obs_source_create("image_source", "Dirt Cover Image", cover_data, nil)
    obs.obs_scene_add(scene, cover_source)
    release_source(cover_source)
    obs.obs_data_release(cover_data)

    local item = obs.obs_scene_find_source(scene, "Dirt Cover Image")
    set_position_with_bounds(item, 0, 0, total_width, total_height)
    obs.obs_sceneitem_set_scale_filter(item, obs.OBS_SCALE_POINT)
end

function _setup_verification_scene()
    local scene = get_scene("Verification")

    local out = get_state_file_string()
    if (out == nil) or not (string.find(out, ";")) then
        return
    end

    local square_size_string = get_square_size_string()
    if square_size_string == nil then
        square_size_string = "90,90"
        obs.script_log(200, "Warning: Could not a loading square size, defaulting to 90x90.")
    end
    local square_size = split_string(square_size_string, ",")
    local square_width = square_size[1]
    local square_height = square_size[2]

    if square_width == nil or square_height == nil then
        square_width = 90
        square_height = 90
        obs.script_log(200, "Warning: Could not a loading square size, defaulting to 90x90.")
    end

    local instance_count = (#(split_string(out, ";"))) - 1

    if instance_count == 0 then
        return
    end

    local total_rows = math.floor(math.sqrt(instance_count)) - 1
    local total_columns = 0

    ::increase_again::
    total_rows = total_rows + 1
    total_columns = math.ceil(instance_count / total_rows)

    size_ratio = math.floor(total_width / total_columns) / math.floor(total_height / total_rows)

    -- No need to make more rows if it's already just a single column
    if total_columns == 1 then
        goto done
    end

    -- Size ratio is the ratio between width and height
    -- If there is not enough width relative to the height, the loading square would take too much space
    if size_ratio < 2.5 then
        goto increase_again
    end

    -- If there is 17.5% or more empty space from unfilled grid spaces, add another row
    missing = (total_rows * total_columns - instance_count) / (total_rows * total_columns)
    if missing > 0.175 then
        goto increase_again
    end

    ::done::
    local i_width = math.floor(total_width / total_columns)
    local i_height = math.floor(total_height / total_rows)

    local filler_source = obs.obs_source_create("color_source", "Filler", nil, nil)


    for instance_num = 1, instance_count, 1 do
        local instance_index = instance_num - 1
        local row = math.floor(instance_index / total_columns)
        local col = math.floor(instance_index % total_columns)

        local verif_cap_source = nil

        if reuse_for_verification then
            verif_cap_source = get_source("Minecraft Capture " .. instance_num)
        else
            local settings = obs.obs_data_create_from_json('{"priority": 1, "window": "Minecraft* - Instance ' ..
                instance_num .. ':GLFW30:javaw.exe"}')
            verif_cap_source = obs.obs_source_create("window_capture", "Verification Capture " .. instance_num,
                settings, nil)
        end

        local verif_item = obs.obs_scene_add(scene, verif_cap_source)
        set_position_with_bounds(verif_item, col * i_width, row * i_height, i_width - i_height, i_height)


        local square_group_item = obs.obs_scene_add_group(scene, "Square " .. instance_num)
        obs.obs_sceneitem_set_scale_filter(square_group_item, obs.OBS_SCALE_POINT)

        local square_group_scene = get_group_as_scene("Square " .. instance_num)

        local filler_item = obs.obs_scene_add(square_group_scene, filler_source)
        set_position_with_bounds(filler_item, 0, 0, 10000, 10000)
        obs.obs_sceneitem_set_visible(filler_item, false)

        local verif_item_2 = obs.obs_scene_add(square_group_scene, verif_cap_source)
        set_position(verif_item_2, 0, 10000)
        obs.obs_sceneitem_set_alignment(verif_item_2, 9)

        set_crop(square_group_item, 0, 10000 - square_height, 10000 - square_width, 0)
        set_position_with_bounds(square_group_item, col * i_width + (i_width - i_height), row * i_height, i_height,
            i_height)

        obs.obs_data_release(settings)
        release_source(verif_cap_source)
    end
    local audio_group_source = get_source("Minecraft Audio")
    obs.obs_scene_add(scene, audio_group_source)
    release_source(filler_source)
    release_source(audio_group_source)
end

function _setup_sound_scene()
    create_scene("Sound")
    local scene = get_scene("Sound")

    -- intuitively the scene item returned from add group would need to be released, but it does not
    if get_group_as_scene("Minecraft Audio") == nil then
        obs.obs_scene_add_group(scene, "Minecraft Audio")
    else
        local source = get_source("Minecraft Audio")
        obs.obs_scene_add(scene, source)
        release_source(source)
    end
    obs.obs_sceneitem_set_visible(obs.obs_scene_find_source(scene, "Minecraft Audio"), false)

    local desk_cap = obs.obs_source_create("wasapi_output_capture", "Desktop Audio", nil, nil)
    obs.obs_scene_add(scene, desk_cap)
    release_source(desk_cap)
end

function _setup_lock_scene()
    create_scene("Lock Display")
    local scene = get_scene("Lock Display")

    -- Example Instances Group
    -- intuitively the scene item returned from add group would need to be released, but it does not
    obs.obs_scene_add_group(scene, "Example Instances")
    local group = get_group_as_scene("Example Instances")
    local group_source = obs.obs_scene_find_source(scene, "Example Instances")
    obs.obs_sceneitem_set_locked(group_source, true)
    obs.obs_sceneitem_set_visible(group_source, false)

    -- Blacksmith Example
    local blacksmith_data = obs.obs_data_create_from_json('{"file":"' ..
        julti_dir .. 'blacksmith_example.png' .. '"}')
    local blacksmith_source = obs.obs_source_create("image_source", "Blacksmith Example", blacksmith_data, nil)
    obs.obs_scene_add(group, blacksmith_source)
    release_source(blacksmith_source)
    obs.obs_data_release(blacksmith_data)

    -- Beach Example
    local beach_data = obs.obs_data_create_from_json('{"file":"' .. julti_dir .. 'beach_example.png' .. '"}')
    local beach_source = obs.obs_source_create("image_source", "Beach Example", beach_data, nil)
    obs.obs_scene_add(group, beach_source)
    release_source(beach_source)
    obs.obs_data_release(beach_data)

    -- Darken
    local darken_data = obs.obs_data_create_from_json('{"color": 3355443200}')
    local darken_source = obs.obs_source_create("color_source", "Darken", darken_data, nil)
    obs.obs_scene_add(scene, darken_source)
    release_source(darken_source)
    obs.obs_data_release(darken_data)
    local item = obs.obs_scene_find_source(scene, "Darken")
    obs.obs_sceneitem_set_visible(item, false)
    set_position_with_bounds(item, 0, 0, total_width, total_height)

    -- Lock image
    local lock_data = obs.obs_data_create_from_json('{"file":"' ..
        julti_dir .. 'lock.png' .. '"}')
    local lock_source = obs.obs_source_create("image_source", "Lock Image", lock_data, nil)
    obs.obs_scene_add(scene, lock_source)
    release_source(lock_source)
    obs.obs_data_release(lock_data)
    set_position_with_bounds(obs.obs_scene_find_source(scene, "Lock Image"), 20, 20, 130, 130)
end

function _setup_julti_scene()
    local out = get_state_file_string()

    local instance_count = (#(split_string(out, ";"))) - 1

    if instance_count == 0 then
        obs.script_log(100, "Julti has not yet been set up (No instances found)! Please setup Julti first!")
        return
    end

    local y = 0
    local i_height = math.floor(total_height / instance_count)
    for i = 1, instance_count, 1 do
        make_minecraft_group(i, total_width, total_height, y, i_height)
        y = y + i_height
    end

    local sound_scene_source = get_source("Sound")
    obs.obs_scene_add(get_scene("Julti"), sound_scene_source)
    release_source(sound_scene_source)
    bring_to_bottom(obs.obs_scene_find_source(get_scene("Julti"), "Sound"))

    _setup_minecraft_sounds(instance_count)

    switch_to_scene("Julti")
end

function _setup_minecraft_sounds(instance_count)
    local group = get_group_as_scene("Minecraft Audio")

    for num = 1, instance_count, 1 do
        -- '{"priority": 1, "window": "Minecraft* - Instance 1:GLFW30:javaw.exe"}'
        local settings = obs.obs_data_create_from_json('{"priority": 1, "window": "Minecraft* - Instance ' ..
            num .. ':GLFW30:javaw.exe"}')
        local source = get_source("Minecraft Audio " .. num)
        if (source == nil) then
            source = obs.obs_source_create("wasapi_process_output_capture", "Minecraft Audio " .. num, settings, nil)
        end
        obs.obs_scene_add(group, source)
        release_source(source)
        obs.obs_data_release(settings)
    end
end

function make_minecraft_group(num, total_width, total_height, y, i_height)
    local scene = get_scene("Julti")

    -- intuitively the scene item returned from add group would need to be released, but it does not
    local group_si = obs.obs_scene_add_group(scene, "Instance " .. num)

    local source = get_source("Lock Display")
    local ldsi = obs.obs_scene_add(scene, source)
    obs.obs_sceneitem_group_add_item(group_si, ldsi)
    release_source(source)

    local source = get_source("Dirt Cover Display")
    obs.obs_sceneitem_group_add_item(group_si, obs.obs_scene_add(scene, source))
    release_source(source)

    local settings = nil
    local source = nil

    if win_cap_instead then
        settings = obs.obs_data_create_from_json('{"priority": 1, "window": "Minecraft* - Instance ' ..
            num .. ':GLFW30:javaw.exe"}')
        source = obs.obs_source_create("window_capture", "Minecraft Capture " .. num, settings, nil)
    else
        settings = obs.obs_data_create_from_json(
            '{"capture_mode": "window","priority": 1,"window": "Minecraft* - Instance '
            .. num .. ':GLFW30:javaw.exe"}')
        source = obs.obs_source_create("game_capture", "Minecraft Capture " .. num, settings, nil)
    end

    S.obs_source_filter_remove(source, S.obs_source_get_filter_by_name(source, "Freeze filter"))

    obs.obs_data_release(settings)
    local mcsi = obs.obs_scene_add(scene, source)
    obs.obs_sceneitem_group_add_item(group_si, mcsi)
    set_position_with_bounds(mcsi, 0, 0, total_width, total_height)
    set_instance_data(num, false, false, false, 0, y, total_width, i_height)
    release_source(source)
end
