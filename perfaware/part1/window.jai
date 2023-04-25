Simp  :: #import "Simp";
Input :: #import "Input";

#import "Math";
#import "Window_Creation";
#import "GL";

Emulator_Window :: struct {
  window: Window_Type;

  screen_width, screen_height: u16;
  window_width, window_height: int;
  framebuffer_textures: [2] Simp.Texture; // our screen will be double-buffered
  front_buffer, back_buffer: int;
  input: Emulator_Input;
}

Emulator_Input :: enum_flags u8 {
  UP;
  DOWN;
  LEFT;
  RIGHT;
  MENU;
}

PIXEL_SCALE :: 4;

emulator_window_init :: (width: u16, height: u16) -> Emulator_Window {
  result: Emulator_Window;
  using result;

  #if OS == .WINDOWS {
    // Windows.SetProcessDPIAware();

    // Windows is very bad at thread-switching by default unless you do this. Sad.
    Windows :: #import "Windows";
    Windows.timeBeginPeriod(1);
  }

  screen_width, screen_height = width, height;
  window_width, window_height = width * PIXEL_SCALE, height * PIXEL_SCALE;
  window = create_window(window_width, window_height, "8086 Emulator");
  Simp.set_render_target(window);

  // Reserve space for front/back buffer textures
  bitmap: Simp.Bitmap = .{
    width  = width,
    height = height,
    format = .RGBA8,
  };

  for *it: framebuffer_textures {
    Simp.texture_load_from_bitmap(it, *bitmap);

    // @Hack: Simp currently has no way to let me change texture filtering without doing this directly.
    glBindTexture(GL_TEXTURE_2D, it.gl_handle);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  }

  front_buffer, back_buffer = 0, 1;

  return result;
}

emulator_window_draw_frame :: (using emu_window: *Emulator_Window, frame: [] u8) {
  assert(frame.count == screen_width*screen_height * 4);

  frame_copy: [..] u8;
  frame_copy.allocator = temporary_allocator;
  array_copy(*frame_copy, frame);

  // Override alpha to full for each pixel since the program may not set the alpha bytes
  for i: 0..screen_width*screen_height-1 {
    frame_copy[i*4+3] = 0xFF;
  }

  bitmap: Simp.Bitmap = .{
    width  = screen_width,
    height = screen_height,
    data   = frame_copy,
    format = .RGBA8,
  };

  Simp.backend_update_texture(*framebuffer_textures[back_buffer], *bitmap);

  Simp.clear_render_target(0, 0, 0, 1);

  Simp.set_shader_for_images(*framebuffer_textures[back_buffer]);
  Simp.immediate_begin();

  v2 :: make_vector2;
  Simp.immediate_quad(
    v2(0, cast(float) window_height),
    v2(cast(float) window_width, cast(float) window_height),
    v2(cast(float) window_width, 0),
    v2(0, 0)
  );
  Simp.immediate_flush();

  front_buffer, back_buffer = swap(front_buffer, back_buffer);
  Simp.swap_buffers(window, vsync = true); // @TODO: Proper frame-limit

  reset_temporary_storage();
}

emulator_window_handle_input :: (using emu_window: *Emulator_Window) -> Emulator_Input {
  Input.update_window_events();

  for Input.events_this_frame {
    if it.type == {
      case .KEYBOARD;
        bit_to_change: Emulator_Input;
        if it.key_code == {
          case .ARROW_UP;
            bit_to_change = .UP;
          case .ARROW_DOWN;
            bit_to_change = .DOWN;
          case .ARROW_LEFT;
            bit_to_change = .LEFT;
          case .ARROW_RIGHT;
            bit_to_change = .RIGHT;
          case .ENTER;
            bit_to_change = .MENU;
        }

        if it.key_pressed {
          input |= bit_to_change;
        }
        else {
          input = input & ~bit_to_change;
        }
    }
  }

  return input;
}
