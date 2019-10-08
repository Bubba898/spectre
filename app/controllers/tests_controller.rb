require 'image_processor'
require 'logger'

class TestsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def new
    @test = Test.new
  end

  def update
    @test = Test.find(params[:id])
    if params[:test][:baseline] == 'true'
      @test.pass = true
      @test.save
      redirect_to project_suite_run_url(@test.run.suite.project, @test.run.suite, @test.run)
    end
  end

  def create
    puts "[chenges] Creation started"
    Rails.logger.debug("debug:: Creation started")
    Logger.new('/proc/1/fd/1').warn('Creation started')
    ImageProcessor.crop(test_params[:screenshot].path, test_params[:crop_area]) if test_params[:crop_area]
    @test = Test.create!(test_params)
    ScreenshotComparison.new(@test, test_params[:screenshot])
    render json: @test.to_json
  end

  private

  def test_params
    params.require(:test).permit(:name, :browser, :size, :screenshot, :run_id, :source_url, :fuzz_level, :highlight_colour, :crop_area, :excluded_areas, :diff_threshhold, :crop_areas)
  end
end
