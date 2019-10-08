require 'image_size'
require 'image_geometry'

class ScreenshotComparison
  attr_reader :pass

  def initialize(test, screenshot)
    determine_baseline_image(test, screenshot)
    image_paths = temp_screenshot_paths(test)
    compare_result = compare_images(test, image_paths)
    @pass = determine_pass(test, image_paths, compare_result)
    test.pass = @pass
    save_screenshots(test, image_paths)
    remove_temp_files(image_paths)
  end

  private

  def temp_screenshot_paths(test)
    {
      baseline: File.join(Rails.root, 'tmp', "#{test.id}_baseline.png"),
      test: File.join(Rails.root, 'tmp', "#{test.id}_test.png"),
      diff: File.join(Rails.root, 'tmp', "#{test.id}_diff.png"),
      mask: File.join(Rails.root, 'tmp', "#{test.id}_mask.png"),
      test_masked: File.join(Rails.root, 'tmp', "#{test.id}_test_masked.png"),
      baseline_masked: File.join(Rails.root, 'tmp', "#{test.id}_baseline_masked.png")
    }
  end

  def compare_images(test, image_paths)
    Rails.logger.debug("debug:: Creation started2")
    Rails.logger.debug("#{test.size} #{test.excluded_areas}")
    canvas = create_canvas(test)
    create_mask = create_mask_command(test.size, image_paths[:mask], test.excluded_areas, test.crop_areas)

    baseline_resize_command = convert_image_command(test.screenshot_baseline.path, image_paths[:baseline], canvas.to_h)
    test_size_command = convert_image_command(test.screenshot.path, image_paths[:test], canvas.to_h)

    overlay_baseline_mask_command = overlay_image_command(image_paths[:baseline], image_paths[:mask], image_paths[:baseline_masked], false)
    overlay_test_mask_command = overlay_image_command(image_paths[:test], image_paths[:mask], image_paths[:test_masked], false)
    overlay_diff_mask_command = overlay_image_command(image_paths[:diff], image_paths[:mask], image_paths[:diff], true)

    compare_command = compare_images_command(image_paths[:baseline_masked], image_paths[:test_masked], image_paths[:diff], test.fuzz_level, test.highlight_colour)
    Rails.logger.debug("Command: text_size:: #{test_size_command}")
    Rails.logger.debug("Command: baseline_size:: #{baseline_resize_command}")
    Rails.logger.debug("Command: create_mask:: #{create_mask}")
    Rails.logger.debug("Command: overlay_baseline:: #{overlay_baseline_mask_command}")
    Rails.logger.debug("Command: overlay_test:: #{overlay_test_mask_command}")
    Rails.logger.debug("Command: compare:: #{compare_command}")
    Rails.logger.debug("Command: overlay_diff:: #{overlay_diff_mask_command}")

    Open3.popen3("#{test_size_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    Open3.popen3("#{baseline_resize_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    Open3.popen3("#{create_mask}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    Open3.popen3("#{overlay_baseline_mask_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    Open3.popen3("#{overlay_test_mask_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    compare_result2 = Open3.popen3("#{compare_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    Open3.popen3("#{overlay_diff_mask_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    #else
    #  compare_command = compare_images_command(image_paths[:baseline], image_paths[:test], image_paths[:diff], test.fuzz_level, test.highlight_colour)
    #  Open3.popen3("#{test_size_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    #  Open3.popen3("#{baseline_resize_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    #  compare_result2 = Open3.popen3("#{compare_command}") { |_stdin, _stdout, stderr, _wait_thr| stderr.read }
    #end 
    return compare_result2
  end

  def overlay_image_command(image_under, image_over, image_out, blend)
    if blend
      shellCommand = "composite #{image_over.shellescape} #{image_under.shellescape} #{image_out.shellescape}"
    else 
      shellCommand = "composite #{image_over.shellescape} #{image_under.shellescape} #{image_out.shellescape}"
    end
  end

  def create_mask_command(size, output_file, exclude_areas, crop_areas)
    shellCommand = "convert -size #{size} xc:transparent -fill yellow "
    if crop_areas != "0,0 0,0"
      crop_areas = crop_areas.split(':')
      crop_areas.each do |item|
        shellCommand += "-draw \"rectangle #{item}\" "
      end
    shellCommand += "-channel A -negate +channel -fill yellow\ "
    end
    if exclude_areas != nil
      exclude_areas = exclude_areas.split(':')
      exclude_areas.each do |item|
        shellCommand += "-draw \"rectangle #{item}\" "
      end
    end
    shellCommand  +=  " #{output_file.shellescape}"
  end


  def compare_images_command(baseline_file, compare_file, diff_file, fuzz, highlight_colour)
    "compare -alpha Off -dissimilarity-threshold 1 -fuzz #{fuzz} -metric AE -highlight-color '##{highlight_colour}' #{baseline_file.shellescape} #{compare_file.shellescape} #{diff_file.shellescape}"
  end

  def create_canvas(test)
    # create a canvas using the baseline's dimensions
    Canvas.new(
      ImageGeometry.new(test.screenshot_baseline.path),
      ImageGeometry.new(test.screenshot.path)
    )
  end

  def determine_baseline_image(test, screenshot)
    # find an existing baseline screenshot for this test
    baseline_test = Baseline.find_by_key(test.key)

    # grab the existing baseline image and cache it against this test
    # otherwise compare against itself
    if baseline_test
      begin
        test.screenshot_baseline = baseline_test.screenshot
      rescue Dragonfly::Job::Fetch::NotFound => e
        test.screenshot_baseline = screenshot
      end
    else
      test.screenshot_baseline = screenshot
    end

    test.save!
  end

  def convert_image_command(input_file, output_file, canvas)
    "convert #{input_file.shellescape} -background white -extent #{canvas[:width]}x#{canvas[:height]} #{output_file.shellescape}"
  end


  def determine_pass(test, image_paths, compare_result)
    Rails.logger.debug("compare_result:: #{compare_result}")
    Rails.logger.debug("diff_threshhold:: #{test.diff_threshhold}")

    begin
      img_size = ImageSize.path(image_paths[:diff]).size.inject(:*)
      pixel_count = (compare_result.to_f / img_size) * 100
      test.diff = pixel_count.round(2)
      (test.diff < test.diff_threshhold.to_f) 
    rescue
      # should probably raise an error here
    end
  end

  def save_screenshots(test, image_paths)
    # assign temporary images to the test to allow dragonfly to process and persist
    test.screenshot = Pathname.new(image_paths[:test])
    test.screenshot_baseline = Pathname.new(image_paths[:baseline])
    test.screenshot_diff = Pathname.new(image_paths[:diff])
    test.save
    test.create_thumbnails
  end

  def remove_temp_files(image_paths)
    # remove the temporary files
    File.delete(image_paths[:test])
    File.delete(image_paths[:baseline])
    File.delete(image_paths[:diff])
    File.delete(image_paths[:mask]) if File.exist?(image_paths[:mask])
    File.delete(image_paths[:test_masked]) if File.exist?(image_paths[:test_masked])
    File.delete(image_paths[:baseline_masked]) if File.exist?(image_paths[:baseline_masked])
  end
end
