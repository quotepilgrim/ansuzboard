local board = {}
local highlighted_squares = {}
local highlighted_move = {}
local colors = {}
local width, height = love.window.getMode()
local board_width, board_height = 8, 8
local square_width = math.min(width / board_width, height / board_height)
local offset_x, offset_y = 0, 0
local selector_offset_x, selector_offset_y = 0, 0
local pieces = {}
local highlight
local grabbed_piece = ""
local drop_piece = false
local grabbed_x, grabbed_y
local dragging = false
local threshold = square_width * 0.1
local select_mode = false
local flip_board = false
local mouse_x, mouse_y = 0, 0

local piece_selector = {
    { "bp", "bn", "bb", "br", "bq", "bk" },
    { "wp", "wn", "wb", "wr", "wq", "wk" },
    { "_x" },
}

local function distance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local function get_coords(x, y)
    local ox, oy = offset_x, offset_y
    if select_mode then
        ox = ox + selector_offset_x
        oy = oy + selector_offset_y
    end
    -- using math.ceil would remove pieces dropped at the top or left edges
    local bx = 1 + math.floor((x - ox) / square_width)
    local by = 1 + math.floor((y - oy) / square_width)
    if not select_mode and flip_board then
        bx = #board[1] + 1 - bx
        by = #board + 1 - by
    end
    return bx, by
end

local function set_highlight(x, y)
    for i = 1, #board do
        for j = 1, #board[1] do
            highlighted_move[i][j] = false
        end
    end
    grabbed_piece = ""
    grabbed_x = 0
    if highlighted_squares[y][x] then
        highlighted_squares[y][x] = false
    else
        highlighted_squares[y][x] = true
    end
end

local function move_piece(x, y)
    if x > board_width or y > board_height or x < 1 or y < 1 then
        grabbed_piece = ""
        grabbed_x, grabbed_y = nil, nil
        return
    end

    if grabbed_piece == "_x" then
        grabbed_piece = ""
    end

    for i = 1, #board do
        for j = 1, #board[1] do
            highlighted_squares[i][j] = false
            highlighted_move[i][j] = false
        end
    end

    if drop_piece then
        board[y][x] = grabbed_piece
        highlighted_move[y][x] = true
        grabbed_piece = ""
        drop_piece = false
    elseif grabbed_piece == "" then
        grabbed_piece = board[y][x]
        grabbed_x, grabbed_y = x, y
    else
        if x ~= grabbed_x or y ~= grabbed_y then
            highlighted_move[y][x] = true
            highlighted_move[grabbed_y][grabbed_x] = true
        end
        board[grabbed_y][grabbed_x] = ""
        board[y][x] = grabbed_piece
        grabbed_piece = ""
    end

    if grabbed_piece == "" then
        grabbed_x, grabbed_y = nil, nil
    end
end

local function draw_square(x, y, ox, oy, mode)
    ox = ox or 0
    oy = oy or 0
    if mode == "flipped" then
        x = #board[1] + 1 - x
        y = #board + 1 - y
    end
    love.graphics.rectangle(
        "fill",
        (x - 1) * square_width + offset_x + ox,
        (y - 1) * square_width + offset_y + oy,
        square_width,
        square_width
    )
end

local function draw_image(image, x, y, ox, oy, mode)
    mode = mode or "board"
    ox = ox or 0
    oy = oy or 0
    local multiplier = square_width
    if mode == "flipped" then
        x = #board[1] + 1 - x
        y = #board + 1 - y
    end
    if mode == "board" or mode == "flipped" then
        ox = ox + offset_x
        oy = oy + offset_y
    elseif mode == "screen" then
        multiplier = 1
        ox = ox - square_width / 2
        oy = oy - square_width / 2
    end
    love.graphics.draw(image, (x - 1) * multiplier + ox, (y - 1) * multiplier + oy, 0, square_width / image:getWidth())
end

local function init_board(fen)
    board = {}
    fen = fen or "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    for i = 1, board_height do
        board[i] = {}
        highlighted_squares[i] = {}
        highlighted_move[i] = {}
        for j = 1, board_width do
            board[i][j] = ""
            highlighted_squares[i][j] = false
            highlighted_move[i][j] = false
        end
    end

    local row, col = 1, 1
    for i = 1, #fen do
        local p = fen:sub(i, i)
        if tonumber(p) then
            col = (col + tonumber(p) - 1) % board_width + 1
            p = nil
        elseif p == "/" then
            row = row + 1
            col = 1
            p = nil
        elseif p == " " then
            break
        end
        if p and p == p:upper() then
            p = "w" .. p:lower()
        elseif p then
            p = "b" .. p
        end
        if p and row <= board_height and col <= board_width then
            board[row][col] = p
            col = col % board_width + 1
        end
    end
end

local function generate_fen()
    local count = 0
    local result = ""

    local castling = ""
    if board[8][5] == "wk" then
        if board[8][8] == "wr" then
            castling = castling .. "K"
        end
        if board[8][1] == "wr" then
            castling = castling .. "Q"
        end
    end
    if board[1][5] == "bk" then
        if board[1][8] == "br" then
            castling = castling .. "k"
        end
        if board[1][1] == "br" then
            castling = castling .. "q"
        end
    end
    if castling == "" then
        castling = "-"
    end

    local function write_count()
        if count > 0 then
            result = result .. tostring(count)
            count = 0
        end
    end
    for i, row in ipairs(board) do
        for _, p in ipairs(row) do
            if p ~= "" then
                if p:sub(1, 1) == "w" then
                    p = p:sub(2, 2):upper()
                else
                    p = p:sub(2, 2)
                end
                write_count()
            else
                count = count + 1
            end
            result = result .. p
        end
        write_count()
        if i < #board then
            result = result .. "/"
        end
    end
    result = result .. " w " .. castling .. " - 0 1"
    return result
end

function love.load()
    pieces.wp = love.graphics.newImage("assets/wp.png")
    pieces.wn = love.graphics.newImage("assets/wn.png")
    pieces.wb = love.graphics.newImage("assets/wb.png")
    pieces.wr = love.graphics.newImage("assets/wr.png")
    pieces.wq = love.graphics.newImage("assets/wq.png")
    pieces.wk = love.graphics.newImage("assets/wk.png")
    pieces.bp = love.graphics.newImage("assets/bp.png")
    pieces.bn = love.graphics.newImage("assets/bn.png")
    pieces.bb = love.graphics.newImage("assets/bb.png")
    pieces.br = love.graphics.newImage("assets/br.png")
    pieces.bq = love.graphics.newImage("assets/bq.png")
    pieces.bk = love.graphics.newImage("assets/bk.png")
    pieces._x = love.graphics.newImage("assets/x.png")
    highlight = love.graphics.newImage("assets/hl.png")

    colors.dark_square = { 181 / 255, 136 / 255, 99 / 255 }
    colors.light_square = { 240 / 255, 217 / 255, 181 / 255 }
    colors.highlight = { 0.25, 1, 1, 0.5 }
    colors.move_highlight = { 1, 0.7, 0.2, 0.5 }
    colors.selector = colors.dark_square

    init_board()
end

function love.update()
    if love.mouse.isDown(1, 2, 3) and distance(mouse_x, mouse_y, love.mouse.getX(), love.mouse.getY()) > threshold then
        dragging = true
        if grabbed_x then
            board[grabbed_y][grabbed_x] = ""
        end
    elseif not love.mouse.isDown(1) then
        dragging = false
    end
    if dragging then
        select_mode = false
    end
end

function love.draw()
    local square_color
    local draw_mode
    if flip_board then
        draw_mode = "flipped"
    end
    for y, _ in ipairs(board) do
        for x, v in ipairs(board[y]) do
            if math.fmod(y + x, 2) == 0 then
                square_color = colors.light_square
            else
                square_color = colors.dark_square
            end

            love.graphics.setColor(square_color)

            draw_square(x, y, 0, 0, draw_mode)

            if grabbed_x == x and grabbed_y == y then
                love.graphics.setColor(colors.highlight)
                draw_image(highlight, x, y, 0, 0, draw_mode)
            end

            if highlighted_squares[y][x] then
                love.graphics.setColor(colors.highlight)
                draw_square(x, y, 0, 0, draw_mode)
            end

            if highlighted_move[y][x] then
                love.graphics.setColor(colors.move_highlight)
                draw_square(x, y, 0, 0, draw_mode)
            end

            love.graphics.setColor(1, 1, 1, 1)
            if pieces[v] then
                draw_image(pieces[v], x, y, 0, 0, draw_mode)
            end
        end
    end

    if select_mode then
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", offset_x, offset_y, square_width * board_width, square_width * board_height)
        for y, _ in ipairs(piece_selector) do
            for x, v in ipairs(piece_selector[y]) do
                love.graphics.setColor(colors.selector)
                draw_square(x, y, selector_offset_x, selector_offset_y)

                love.graphics.setColor(1, 1, 1)
                draw_image(pieces[v], x, y, selector_offset_x, selector_offset_y)
            end
        end
    end

    if (dragging or drop_piece) and grabbed_piece ~= "" then
        draw_image(pieces[grabbed_piece], love.mouse.getX(), love.mouse.getY(), 0, 0, "screen")
    end
end

function love.keypressed(key)
    local fen
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        init_board()
    elseif key == "f" then
        flip_board = not flip_board
    elseif key == "s" or key == "tab" then
        select_mode = not select_mode
        local max_x = math.min(
            love.mouse.getX() - offset_x - #piece_selector[1] * square_width / 2,
            #board[1] * square_width - #piece_selector[1] * square_width
        )
        local max_y = math.min(
            love.mouse.getY() - offset_y - (#piece_selector - 1) * square_width / 2,
            #board * square_width - #piece_selector * square_width
        )
        selector_offset_x = math.max(0, max_x)
        selector_offset_y = math.max(0, max_y)
    elseif key == "=" then
        if love.keyboard.isDown("rshift", "lshift") then
            board_height = board_height + 1
        else
            board_width = board_width + 1
        end
        init_board("")
        square_width = math.min(width / board_width, height / board_height)
        love.resize(width, height)
    elseif key == "-" then
        if love.keyboard.isDown("rshift", "lshift") then
            board_height = board_height - 1
        else
            board_width = board_width - 1
        end
        init_board("")
        square_width = math.min(width / board_width, height / board_height)
        love.resize(width, height)
    elseif key == "c" then
        fen = generate_fen()
        love.system.setClipboardText(fen)
        print(fen)
    elseif key == "v" then
        fen = love.system.getClipboardText()
        init_board(fen)
    end
end

function love.mousepressed(x, y, button)
    local bx, by = get_coords(x, y)
    mouse_x = love.mouse.getX()
    mouse_y = love.mouse.getY()

    if select_mode then
        if bx > #piece_selector[1] or by > #piece_selector or bx < 1 or by < 1 then
            select_mode = false
            return
        end

        if not piece_selector[by][bx] then
            select_mode = false
            return
        end

        drop_piece = true
        grabbed_piece = piece_selector[by][bx]
        return
    end

    if bx > board_width or by > board_height or bx < 1 or by < 1 then
        return
    end

    if not drop_piece and (love.keyboard.isDown("lshift", "rshift") or button == 3) then
        if board[by][bx] == "" then
            return
        end
        drop_piece = true
        grabbed_piece = board[by][bx]
        if grabbed_piece == "" then
            return
        end
        if button == 1 then
            grabbed_piece = ""
            move_piece(bx, by)
        end
        return
    end

    if button == 1 or drop_piece then
        move_piece(bx, by)
    elseif button == 2 then
        set_highlight(bx, by)
        grabbed_x, grabbed_y = nil, nil
    end
end

function love.mousereleased(x, y, button)
    if select_mode then
        select_mode = false
        return
    end
    local bx, by = get_coords(x, y)
    if not dragging or grabbed_piece == "" then
        return
    end
    if button == 1 or dragging then
        move_piece(bx, by)
    end
end

function love.resize(w, h)
    square_width = math.min(w / board_width, h / board_height)
    threshold = square_width * 0.1
    if w / board_width > h / board_height then
        offset_x = w / 2 - board_width * square_width / 2
        offset_y = 0
    else
        offset_x = 0
        offset_y = h / 2 - board_height * square_width / 2
    end
    width, height = w, h
end
