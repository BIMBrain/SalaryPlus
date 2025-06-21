# frozen_string_literal: true

class EmployeeAuthController < ApplicationController
  layout 'employee_portal'
  
  def login
    # 顯示員工登入頁面
  end
  
  def authenticate
    employee = find_employee_by_credentials
    
    if employee
      session[:employee_id] = employee.id
      redirect_to employee_portal_index_path, notice: '登入成功'
    else
      flash.now[:alert] = '員工編號或身分證字號錯誤'
      render :login
    end
  end
  
  def logout
    session[:employee_id] = nil
    redirect_to employee_login_path, notice: '已成功登出'
  end
  
  private
  
  def find_employee_by_credentials
    employee_number = params[:employee_number]&.strip
    id_number = params[:id_number]&.strip
    
    return nil if employee_number.blank? || id_number.blank?
    
    # 使用員工編號和身分證字號作為認證
    Employee.find_by(
      employee_number: employee_number,
      id_number: id_number
    )
  end
end
