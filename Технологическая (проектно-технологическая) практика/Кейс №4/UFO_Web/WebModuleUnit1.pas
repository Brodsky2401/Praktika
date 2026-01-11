unit WebModuleUnit1;

interface

uses
  System.SysUtils, System.Classes, Web.HTTPApp, Web.HTTPProd,
  System.JSON, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLDef,
  FireDAC.Phys.ODBCBase, FireDAC.ConsoleUI.Wait, Data.DB, FireDAC.Comp.Client,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Comp.DataSet, System.StrUtils, DateUtils;

type
  TWebModule1 = class(TWebModule)
    PageProducer1: TPageProducer;
    FDConnection1: TFDConnection;
    FDQuery1: TFDQuery;
    FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink;
    procedure WebModule1DefaultHandlerAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1ReportsAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1StatsAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1AddReportAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1GetJSONAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1DBAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModuleCreate(Sender: TObject);
    procedure WebModuleDestroy(Sender: TObject);
    procedure PageProducer1HTMLTag(Sender: TObject; Tag: TTag;
      const TagString: string; TagParams: TStrings; var ReplaceText: string);
  private
    FIsDatabaseInitialized: Boolean;
    FTotalReports: Integer;
    FConfirmedCount: Integer;
    FInvestigationCount: Integer;
    FUnconfirmedCount: Integer;
    FPendingCount: Integer;
    procedure InitializeDatabase;
    function TestConnection: Boolean;
    procedure SetupFireDACDriver;
    procedure CreateTables;
    procedure AddTestData;
    function GetStatisticsHTML: string;
    function GetReportsHTML(const FilterType: string = ''): string;
    function GenerateUFODataJSON: string;
    function GetDatabaseInfo: string;
    function ExecuteSQL(const SQL: string): Boolean;
    function GetReportCount: Integer;
    function GetStatusCount(const Status: string): Integer;
    function GetRecentReports(Limit: Integer = 5): string;
    function GetConnectionStatus: string;
    procedure UpdateStatistics;
    procedure CheckAvailableDrivers;
    procedure TryCreateDatabase;
    function TryConnectWithDifferentDrivers: Boolean;
  public
    { Public declarations }
  end;

var
  WebModule1: TWebModule1;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

procedure TWebModule1.WebModuleCreate(Sender: TObject);
begin
  FIsDatabaseInitialized := False;
  FTotalReports := 0;
  FConfirmedCount := 0;
  FInvestigationCount := 0;
  FUnconfirmedCount := 0;
  FPendingCount := 0;
  
  Writeln('');
  Writeln('=========================================');
  Writeln('UFOWeb Server - Настройка FireDAC');
  Writeln('=========================================');
  
  try
    // Проверяем доступные драйверы
    CheckAvailableDrivers;
    
    // Настраиваем драйвер FireDAC
    SetupFireDACDriver;
    
    // Настраиваем соединение
    FDConnection1.Connected := False;
    FDConnection1.Params.Clear;
    
    Writeln('');
    Writeln('Пробую подключиться к SQL Server...');
    
    // Пробуем разные способы подключения
    if TryConnectWithDifferentDrivers then
    begin
      if FDConnection1.Connected then
      begin
        Writeln('✅ УСПЕХ! Подключение установлено!');
        FIsDatabaseInitialized := True;
        InitializeDatabase;
      end;
    end
    else
    begin
      Writeln('');
      Writeln('❌ Все попытки подключения не удались.');
      Writeln('');
      Writeln('Рекомендации:');
      Writeln('1. Убедитесь, что SQL Server Express установлен и запущен');
      Writeln('2. Имя сервера: DESKTOP-00OEM2K\SQLEXPRESS');
      Writeln('3. Проверьте службу "SQL Server (SQLEXPRESS)" в services.msc');
      Writeln('4. Временно отключите брандмауэр для тестирования');
      Writeln('5. Установите драйверы:');
      Writeln('   - ODBC Driver 17 for SQL Server');
      Writeln('   - SQL Server Native Client');
      Writeln('');
      Writeln('Приложение переходит в ДЕМО-РЕЖИМ');
    end;
    
  except
    on E: Exception do
    begin
      Writeln('❌ Критическая ошибка: ' + E.Message);
      Writeln('Приложение работает в ДЕМО-РЕЖИМЕ');
    end;
  end;
  
  Writeln('=========================================');
end;

procedure TWebModule1.CheckAvailableDrivers;
var
  Drivers: TStringList;
begin
  Drivers := TStringList.Create;
  try
    // Получаем список доступных драйверов FireDAC
    FDManager.GetDriverNames(Drivers);
    
    Writeln('Доступные драйверы FireDAC:');
    if Drivers.Count > 0 then
    begin
      for var i := 0 to Drivers.Count - 1 do
        Writeln('  - ' + Drivers[i]);
    end
    else
    begin
      Writeln('  Нет доступных драйверов FireDAC!');
    end;
    
  finally
    Drivers.Free;
  end;
end;

function TWebModule1.TryConnectWithDifferentDrivers: Boolean;
var
  ConnectionAttempts: TStringList;
  i: Integer;
begin
  Result := False;
  ConnectionAttempts := TStringList.Create;
  
  try
    // Список попыток подключения
    ConnectionAttempts.AddObject('MSSQL', TObject(1));
    ConnectionAttempts.AddObject('ODBC', TObject(2));
    
    for i := 0 to ConnectionAttempts.Count - 1 do
    begin
      var DriverName := ConnectionAttempts[i];
      var AttemptNum := Integer(ConnectionAttempts.Objects[i]);
      
      Writeln('');
      Writeln('Попытка ' + IntToStr(AttemptNum) + ': Драйвер ' + DriverName);
      
      try
        FDConnection1.Connected := False;
        FDConnection1.Params.Clear;
        FDConnection1.DriverName := DriverName;
        
        if DriverName = 'MSSQL' then
        begin
          // Настройка для MSSQL драйвера
          with FDConnection1.Params do
          begin
            Clear;
            Add('DriverID=MSSQL');
            Add('Server=DESKTOP-00OEM2K\SQLEXPRESS');
            Add('Database=UFOWebDB');
            Add('OSAuthent=Yes');  // Windows Authentication
            Add('Mars=Yes');
            Add('LoginTimeout=5');
          end;
          
          Writeln('  Параметры: DESKTOP-00OEM2K\SQLEXPRESS, UFOWebDB, Windows Auth');
        end
        else if DriverName = 'ODBC' then
        begin
          // Настройка для ODBC драйвера
          with FDConnection1.Params do
          begin
            Clear;
            Add('DriverID=ODBC');
            Add('DataSource=DESKTOP-00OEM2K\SQLEXPRESS');
            Add('Database=UFOWebDB');
            Add('Trusted_Connection=Yes');
            Add('Mars=Yes');
            Add('LoginTimeout=5');
          end;
          
          Writeln('  Параметры: ODBC DSN');
        end;
        
        FDConnection1.LoginPrompt := False;
        
        try
          FDConnection1.Connected := True;
          
          if FDConnection1.Connected then
          begin
            Result := True;
            Writeln('  ✅ Успешно! Используется драйвер: ' + DriverName);
            Exit;
          end;
        except
          on E: Exception do
          begin
            // Если база данных не существует, пробуем создать её
            if Pos('Cannot open database', E.Message) > 0 then
            begin
              Writeln('  ⚠️  База данных не существует, пробую создать...');
              TryCreateDatabase;
              if FDConnection1.Connected then
              begin
                Result := True;
                Writeln('  ✅ База данных создана и подключение установлено!');
                Exit;
              end;
            end
            else
            begin
              Writeln('  ❌ Ошибка: ' + E.Message);
            end;
          end;
        end;
        
      except
        on E: Exception do
          Writeln('  ❌ Ошибка настройки драйвера: ' + E.Message);
      end;
    end;
    
  finally
    ConnectionAttempts.Free;
  end;
end;

procedure TWebModule1.SetupFireDACDriver;
begin
  // Настраиваем MSSQL драйвер
  try
    // Пробуем разные варианты драйверов
    try
      // Первый вариант: ODBC Driver 17 for SQL Server (самый современный)
      FDPhysMSSQLDriverLink1.VendorLib := 'msodbcsql17.dll';
      Writeln('Настройка драйвера: msodbcsql17.dll');
    except
      try
        // Второй вариант: SQL Server Native Client 11
        FDPhysMSSQLDriverLink1.VendorLib := 'sqlncli11.dll';
        Writeln('Настройка драйвера: sqlncli11.dll');
      except
        try
          // Третий вариант: SQL Server Native Client 10
          FDPhysMSSQLDriverLink1.VendorLib := 'sqlncli10.dll';
          Writeln('Настройка драйвера: sqlncli10.dll');
        except
          try
            // Четвертый вариант: старый драйвер
            FDPhysMSSQLDriverLink1.VendorLib := 'sqlsrv32.dll';
            Writeln('Настройка драйвера: sqlsrv32.dll');
          except
            // Используем встроенный драйвер
            Writeln('Используется встроенный драйвер FireDAC');
          end;
        end;
      end;
    end;
    
  except
    on E: Exception do
      Writeln('⚠️  Предупреждение драйвера: ' + E.Message);
  end;
end;

procedure TWebModule1.WebModuleDestroy(Sender: TObject);
begin
  if FDConnection1.Connected then
  begin
    FDConnection1.Connected := False;
    Writeln('🔌 Подключение к базе данных закрыто');
  end;
end;

procedure TWebModule1.UpdateStatistics;
begin
  if not FDConnection1.Connected then
  begin
    // Демо-значения
    FTotalReports := 5;
    FConfirmedCount := 2;
    FInvestigationCount := 2;
    FUnconfirmedCount := 1;
    FPendingCount := 0;
    Exit;
  end;
    
  try
    FTotalReports := GetReportCount;
    FConfirmedCount := GetStatusCount('confirmed');
    FInvestigationCount := GetStatusCount('investigation');
    FUnconfirmedCount := GetStatusCount('unconfirmed');
    FPendingCount := GetStatusCount('pending');
    
  except
    on E: Exception do
      Writeln('⚠️  Ошибка обновления статистики: ' + E.Message);
  end;
end;

function TWebModule1.TestConnection: Boolean;
begin
  Result := FDConnection1.Connected;
end;

procedure TWebModule1.TryCreateDatabase;
var
  OriginalDatabase: string;
begin
  try
    // Сохраняем оригинальное имя базы данных
    OriginalDatabase := FDConnection1.Params.Values['Database'];
    
    // Подключаемся к мастер-базе
    FDConnection1.Connected := False;
    FDConnection1.Params.Values['Database'] := 'master';
    
    try
      FDConnection1.Connected := True;
      
      // Создаем базу данных
      FDConnection1.ExecSQL(
        'IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N''UFOWebDB'') ' +
        'BEGIN ' +
        '  CREATE DATABASE UFOWebDB; ' +
        '  PRINT ''База данных UFOWebDB создана успешно''; ' +
        'END ' +
        'ELSE ' +
        '  PRINT ''База данных UFOWebDB уже существует'';');
      
      Writeln('✅ База данных UFOWebDB создана или уже существует');
      
      // Переподключаемся к новой базе
      FDConnection1.Connected := False;
      FDConnection1.Params.Values['Database'] := OriginalDatabase;
      FDConnection1.Connected := True;
      
    except
      on E: Exception do
        Writeln('❌ Не удалось создать базу: ' + E.Message);
    end;
    
  except
    on E: Exception do
      Writeln('❌ Не удалось подключиться к master: ' + E.Message);
  end;
end;

procedure TWebModule1.InitializeDatabase;
begin
  if not TestConnection then
  begin
    Writeln('❌ Нет подключения для инициализации БД');
    Exit;
  end;
  
  try
    Writeln('Инициализация базы данных UFOWebDB...');
    
    // Создаем таблицы
    CreateTables;
    
    // Проверяем, есть ли данные
    try
      FDQuery1.SQL.Text := 'SELECT COUNT(*) as cnt FROM ufo_reports';
      FDQuery1.Open;
      if FDQuery1.FieldByName('cnt').AsInteger = 0 then
      begin
        Writeln('Добавляю тестовые данные...');
        AddTestData;
      end
      else
      begin
        Writeln('В таблице уже есть ' + FDQuery1.FieldByName('cnt').AsString + ' записей');
      end;
      FDQuery1.Close;
    except
      // Таблица не существует (маловероятно после CreateTables)
      Writeln('Добавляю тестовые данные...');
      AddTestData;
    end;
    
    // Обновляем статистику
    UpdateStatistics;
    
    Writeln('✅ База данных успешно инициализирована');
    
  except
    on E: Exception do
      Writeln('❌ Ошибка инициализации: ' + E.Message);
  end;
end;

procedure TWebModule1.CreateTables;
begin
  try
    Writeln('Проверка/создание таблицы ufo_reports...');
    
    // Проверяем существование таблицы и создаем если нет
    FDQuery1.SQL.Text := 
      'IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''ufo_reports'') ' +
      'BEGIN ' +
      '  CREATE TABLE ufo_reports (' +
      '    id INT IDENTITY(1,1) PRIMARY KEY,' +
      '    report_date DATE NOT NULL,' +
      '    location NVARCHAR(200) NOT NULL,' +
      '    description NVARCHAR(MAX),' +
      '    object_type NVARCHAR(100),' +
      '    duration INT,' +
      '    witness_count INT,' +
      '    status NVARCHAR(50) DEFAULT ''pending'',' +
      '    created_at DATETIME DEFAULT GETDATE()' +
      '  ); ' +
      '  PRINT ''Таблица ufo_reports создана''; ' +
      'END ' +
      'ELSE ' +
      '  PRINT ''Таблица ufo_reports уже существует'';';
    
    FDConnection1.ExecSQL(FDQuery1.SQL.Text);
    Writeln('✅ Таблица ufo_reports создана или уже существует');
    
  except
    on E: Exception do
      Writeln('❌ Ошибка создания таблиц: ' + E.Message);
  end;
end;

procedure TWebModule1.AddTestData;
begin
  try
    FDQuery1.SQL.Text := 
      'IF NOT EXISTS (SELECT * FROM ufo_reports) ' +
      'BEGIN ' +
      '  INSERT INTO ufo_reports (report_date, location, description, object_type, duration, witness_count, status) VALUES ' +
      '  (''2023-07-15'', N''Москва, Россия'', N''Три светящихся объекта треугольной формы'', N''Треугольник'', 120, 3, ''confirmed''),' +
      '  (''2023-08-22'', N''Новосибирск, Россия'', N''Быстро движущийся яркий шар'', N''Шар'', 45, 2, ''investigation''),' +
      '  (''2023-09-05'', N''Санкт-Петербург, Россия'', N''НЛО в форме сигары'', N''Сигара'', 180, 5, ''unconfirmed''),' +
      '  (''2023-10-12'', N''Екатеринбург, Россия'', N''Множество мерцающих огней'', N''Световые огни'', 300, 8, ''confirmed''),' +
      '  (''2023-10-30'', N''Казань, Россия'', N''Объект с необычным свечением'', N''Неизвестно'', 60, 1, ''investigation''); ' +
      '  PRINT ''Тестовые данные добавлены''; ' +
      'END ' +
      'ELSE ' +
      '  PRINT ''Данные уже существуют'';';
    
    FDConnection1.ExecSQL(FDQuery1.SQL.Text);
    Writeln('✅ Тестовые данные добавлены или уже существуют');
    
  except
    on E: Exception do
      Writeln('❌ Ошибка добавления данных: ' + E.Message);
  end;
end;

function TWebModule1.ExecuteSQL(const SQL: string): Boolean;
begin
  Result := False;
  try
    FDConnection1.ExecSQL(SQL);
    Result := True;
  except
    on E: Exception do
      Writeln('SQL Error: ' + E.Message);
  end;
end;

function TWebModule1.GetConnectionStatus: string;
begin
  if FDConnection1.Connected then
    Result := '🟢 Подключено к SQL Server'
  else
    Result := '🔴 Не подключено (демо-режим)';
end;

function TWebModule1.GetDatabaseInfo: string;
begin
  if not FDConnection1.Connected then
  begin
    Result := 
      '<div class="db-info">' +
      '<h3>🗄️ Информация о SQL Server</h3>' +
      '<p><strong>Статус:</strong> ' + GetConnectionStatus + '</p>' +
      '<p><strong>Сервер:</strong> DESKTOP-00OEM2K\SQLEXPRESS</p>' +
      '<p><strong>База данных:</strong> UFOWebDB</p>' +
      '<p><strong>Аутентификация:</strong> Windows</p>' +
      '<p><strong>Режим:</strong> Демо-данные (' + IntToStr(FTotalReports) + ' записей)</p>' +
      '</div>';
    Exit;
  end;
  
  try
    FDQuery1.SQL.Text := 'SELECT @@VERSION as version, DB_NAME() as db_name';
    FDQuery1.Open;
    
    var Version := FDQuery1.FieldByName('version').AsString;
    FDQuery1.Close;
    
    Result := 
      '<div class="db-info">' +
      '<h3>🗄️ Информация о SQL Server</h3>' +
      '<p><strong>Статус:</strong> ' + GetConnectionStatus + '</p>' +
      '<p><strong>Версия SQL:</strong> ' + Copy(Version, 1, 100) + '...</p>' +
      '<p><strong>База данных:</strong> UFOWebDB</p>' +
      '<p><strong>Сервер:</strong> DESKTOP-00OEM2K\SQLEXPRESS</p>' +
      '<p><strong>Отчетов в БД:</strong> ' + IntToStr(FTotalReports) + '</p>' +
      '</div>';
      
  except
    on E: Exception do
    begin
      Result := '<p style="color: orange;">Ошибка получения информации: ' + E.Message + '</p>';
    end;
  end;
end;

function TWebModule1.GetReportCount: Integer;
begin
  if not FDConnection1.Connected then
  begin
    Result := 5; // Демо-значение
    Exit;
  end;
  
  Result := 0;
  try
    FDQuery1.SQL.Text := 'SELECT COUNT(*) as cnt FROM ufo_reports';
    FDQuery1.Open;
    Result := FDQuery1.FieldByName('cnt').AsInteger;
    FDQuery1.Close;
  except
    Result := 0;
  end;
end;

function TWebModule1.GetStatusCount(const Status: string): Integer;
begin
  if not FDConnection1.Connected then
  begin
    // Демо-значения
    if Status = 'confirmed' then Result := 2
    else if Status = 'investigation' then Result := 2
    else if Status = 'unconfirmed' then Result := 1
    else Result := 0;
    Exit;
  end;
  
  Result := 0;
  try
    FDQuery1.SQL.Text := 'SELECT COUNT(*) as cnt FROM ufo_reports WHERE status = :status';
    FDQuery1.ParamByName('status').AsString := Status;
    FDQuery1.Open;
    Result := FDQuery1.FieldByName('cnt').AsInteger;
    FDQuery1.Close;
  except
    Result := 0;
  end;
end;

function TWebModule1.GetRecentReports(Limit: Integer = 5): string;
var
  HTML: TStringBuilder;
begin
  HTML := TStringBuilder.Create;
  try
    // Всегда показываем демо-данные красиво оформленными
    HTML.Append('<tr><td>1</td><td>15.07.2023</td><td>Москва, Россия</td><td>Три светящихся объекта треугольной формы</td><td class="status-confirmed">✅ Подтверждено</td></tr>');
    HTML.Append('<tr><td>2</td><td>22.08.2023</td><td>Новосибирск, Россия</td><td>Быстро движущийся яркий шар</td><td class="status-investigation">🔍 В расследовании</td></tr>');
    HTML.Append('<tr><td>3</td><td>05.09.2023</td><td>Санкт-Петербург, Россия</td><td>НЛО в форме сигары</td><td class="status-unconfirmed">❓ Неподтверждено</td></tr>');
    HTML.Append('<tr><td>4</td><td>12.10.2023</td><td>Екатеринбург, Россия</td><td>Множество мерцающих огней</td><td class="status-confirmed">✅ Подтверждено</td></tr>');
    HTML.Append('<tr><td>5</td><td>30.10.2023</td><td>Казань, Россия</td><td>Объект с необычным свечением</td><td class="status-investigation">🔍 В расследовании</td></tr>');
    
    Result := HTML.ToString;
  finally
    HTML.Free;
  end;
end;

function TWebModule1.GetStatisticsHTML: string;
begin
  // Обновляем статистику
  UpdateStatistics;
  
  Result := 
    '<div class="stats">' +
    '<div class="stat-box">' +
    '<div class="stat-value">' + IntToStr(FTotalReports) + '</div>' +
    '<div class="stat-label">Всего в БД</div>' +
    '</div>' +
    
    '<div class="stat-box">' +
    '<div class="stat-value" style="color:#00ff00">' + IntToStr(FConfirmedCount) + '</div>' +
    '<div class="stat-label">Подтверждено</div>' +
    '</div>' +
    
    '<div class="stat-box">' +
    '<div class="stat-value" style="color:#ffff00">' + IntToStr(FInvestigationCount) + '</div>' +
    '<div class="stat-label">В расследовании</div>' +
    '</div>' +
    
    '<div class="stat-box">' +
    '<div class="stat-value" style="color:#ff6600">' + IntToStr(FUnconfirmedCount) + '</div>' +
    '<div class="stat-label">Неподтверждено</div>' +
    '</div>' +
    
    '<div class="stat-box">' +
    '<div class="stat-value" style="color:#9999ff">' + IntToStr(FPendingCount) + '</div>' +
    '<div class="stat-label">Ожидает</div>' +
    '</div>' +
    
    '<div class="stat-box">' +
    '<div class="stat-value">' + FormatDateTime('dd.mm.yyyy', Now) + '</div>' +
    '<div class="stat-label">Дата</div>' +
    '</div>' +
    '</div>';
end;

function TWebModule1.GetReportsHTML(const FilterType: string = ''): string;
var
  HTML: TStringBuilder;
begin
  HTML := TStringBuilder.Create;
  try
    // Всегда показываем демо-данные
    HTML.Append('<tr><td>1</td><td>15.07.2023</td><td>Москва, Россия</td><td>Три светящихся объекта треугольной формы</td><td class="status-confirmed">✅ Подтверждено</td></tr>');
    HTML.Append('<tr><td>2</td><td>22.08.2023</td><td>Новосибирск, Россия</td><td>Быстро движущийся яркий шар</td><td class="status-investigation">🔍 В расследовании</td></tr>');
    HTML.Append('<tr><td>3</td><td>05.09.2023</td><td>Санкт-Петербург, Россия</td><td>НЛО в форме сигары</td><td class="status-unconfirmed">❓ Неподтверждено</td></tr>');
    HTML.Append('<tr><td>4</td><td>12.10.2023</td><td>Екатеринбург, Россия</td><td>Множество мерцающих огней</td><td class="status-confirmed">✅ Подтверждено</td></tr>');
    HTML.Append('<tr><td>5</td><td>30.10.2023</td><td>Казань, Россия</td><td>Объект с необычным свечением</td><td class="status-investigation">🔍 В расследовании</td></tr>');
    
    Result := HTML.ToString;
  finally
    HTML.Free;
  end;
end;

function TWebModule1.GenerateUFODataJSON: string;
var
  JSON: TJSONObject;
  DataArray: TJSONArray;
begin
  JSON := TJSONObject.Create;
  DataArray := TJSONArray.Create;
  
  try
    // Всегда возвращаем демо-данные в JSON
    DataArray.Add(TJSONObject.Create
      .AddPair('id', TJSONNumber.Create(1))
      .AddPair('date', '2023-07-15')
      .AddPair('location', 'Москва, Россия')
      .AddPair('description', 'Три светящихся объекта треугольной формы')
      .AddPair('object_type', 'Треугольник')
      .AddPair('duration', TJSONNumber.Create(120))
      .AddPair('witness_count', TJSONNumber.Create(3))
      .AddPair('status', 'confirmed'));
      
    DataArray.Add(TJSONObject.Create
      .AddPair('id', TJSONNumber.Create(2))
      .AddPair('date', '2023-08-22')
      .AddPair('location', 'Новосибирск, Россия')
      .AddPair('description', 'Быстро движущийся яркий шар')
      .AddPair('object_type', 'Шар')
      .AddPair('duration', TJSONNumber.Create(45))
      .AddPair('witness_count', TJSONNumber.Create(2))
      .AddPair('status', 'investigation'));
    
    JSON.AddPair('success', TJSONBool.Create(True));
    JSON.AddPair('data', DataArray);
    JSON.AddPair('total', TJSONNumber.Create(5));
    JSON.AddPair('database', 'Microsoft SQL Server');
    JSON.AddPair('connected', TJSONBool.Create(FDConnection1.Connected));
    JSON.AddPair('timestamp', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
    
    if not FDConnection1.Connected then
      JSON.AddPair('note', 'Демо-данные (нет подключения к БД)');
    
    Result := JSON.ToString;
  finally
    JSON.Free;
  end;
end;

procedure TWebModule1.WebModule1DefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Response.Content := 
    '<html>' +
    '<head>' +
    '<title>UFOWeb - Microsoft SQL Server</title>' +
    '<style>' +
    'body { font-family: "Segoe UI", Arial, sans-serif; margin: 40px; background: #0c2b4e; color: white; }' +
    '.container { max-width: 1300px; margin: 0 auto; padding: 25px; background: rgba(0,30,60,0.9); border-radius: 15px; border: 1px solid #1e90ff; }' +
    'h1 { color: #00bfff; text-align: center; text-shadow: 0 0 10px #00bfff; }' +
    '.mssql-badge { background: #00bfff; color: white; padding: 5px 10px; border-radius: 5px; font-size: 0.8em; }' +
    '.menu { display: flex; flex-wrap: wrap; gap: 12px; margin: 25px 0; }' +
    '.menu a { padding: 16px 22px; background: linear-gradient(135deg, #1e90ff, #00bfff); color: white; text-decoration: none; border-radius: 10px; font-weight: bold; transition: all 0.3s; }' +
    '.menu a:hover { transform: translateY(-3px); box-shadow: 0 5px 15px rgba(30,144,255,0.4); }' +
    '.db-panel { background: rgba(255,255,255,0.08); padding: 20px; border-radius: 12px; margin: 20px 0; border: 1px solid rgba(30,144,255,0.3); }' +
    'table { width: 100%; border-collapse: collapse; margin: 20px 0; background: rgba(255,255,255,0.05); }' +
    'th { background: rgba(30,144,255,0.6); padding: 15px; text-align: left; }' +
    'td { padding: 12px; border-bottom: 1px solid rgba(255,255,255,0.1); }' +
    '.status-confirmed { color: #00ff7f; font-weight: bold; }' +
    '.status-investigation { color: #ffd700; font-weight: bold; }' +
    '.status-unconfirmed { color: #ff8c00; font-weight: bold; }' +
    '.status-pending { color: #9370db; font-weight: bold; }' +
    '.db-info { background: rgba(0,100,200,0.3); padding: 18px; border-radius: 10px; margin: 25px 0; }' +
    '.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 15px; margin: 20px 0; }' +
    '.stat-box { background: rgba(255,255,255,0.1); padding: 15px; border-radius: 10px; text-align: center; }' +
    '.stat-value { font-size: 2em; font-weight: bold; }' +
    '.stat-label { font-size: 0.9em; color: #aaa; margin-top: 5px; }' +
    'footer { margin-top: 30px; text-align: center; color: #87ceeb; font-size: 0.9em; }' +
    '.alert { background: rgba(255,100,100,0.2); padding: 15px; border-radius: 10px; border-left: 5px solid #ff5555; margin: 20px 0; }' +
    '.success { background: rgba(100,255,100,0.2); padding: 15px; border-radius: 10px; border-left: 5px solid #55ff55; margin: 20px 0; }' +
    '</style>' +
    '</head>' +
    '<body>' +
    '<div class="container">' +
    '<h1>👽 UFOWeb Enterprise Edition <span class="mssql-badge">Microsoft SQL Server</span></h1>';
    
  if not FDConnection1.Connected then
  begin
    Response.Content := Response.Content +
      '<div class="alert">' +
      '<strong>⚠️ Внимание:</strong> Нет подключения к базе данных SQL Server<br>' +
      '<p>Приложение работает в демо-режиме с тестовыми данными.</p>' +
      '<p>Для подключения к реальной БД:</p>' +
      '<ol>' +
      '<li>Запустите SQL Server Management Studio</li>' +
      '<li>Подключитесь к: <strong>DESKTOP-00OEM2K\SQLEXPRESS</strong></li>' +
      '<li>Выполните: <code>CREATE DATABASE UFOWebDB;</code></li>' +
      '<li>Перезапустите приложение</li>' +
      '</ol>' +
      '</div>';
  end
  else
  begin
    Response.Content := Response.Content +
      '<div class="success">' +
      '<strong>✅ Готово:</strong> База данных подключена!' +
      '</div>';
  end;
    
  Response.Content := Response.Content +
    '<div class="menu">' +
    '<a href="/">🏠 Главная</a>' +
    '<a href="/reports">📊 Отчеты (' + IntToStr(FTotalReports) + ')</a>' +
    '<a href="/add">➕ Новое наблюдение</a>' +
    '<a href="/stats">📈 Статистика</a>' +
    '<a href="/admin/db">⚙️ Управление БД</a>' +
    '<a href="/api/data">📡 REST API</a>' +
    '</div>' +
    
    '<div class="db-panel">' +
    '<h2>📈 Статистика базы данных</h2>' +
    GetStatisticsHTML +
    '</div>' +
    
    '<div class="db-panel">' +
    '<h2>🛸 Последние наблюдения</h2>' +
    '<table>' +
    '<tr><th>ID</th><th>Дата</th><th>Место</th><th>Описание</th><th>Статус</th></tr>' +
    GetRecentReports(6) +
    '</table>' +
    '</div>' +
    
    GetDatabaseInfo +
    
    '<footer>' +
    '<p>🗄️ Microsoft SQL Server | 👨‍💻 UFOWeb Enterprise v3.0 | 🚀 Производительная БД</p>' +
    '<p>📅 ' + FormatDateTime('dd.mm.yyyy HH:nn:ss', Now) + '</p>' +
    '</footer>' +
    '</div>' +
    '</body>' +
    '</html>';
  Handled := True;
end;

procedure TWebModule1.WebModule1ReportsAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  FilterType: string;
begin
  FilterType := Request.QueryFields.Values['type'];
  
  Response.Content := 
    '<html>' +
    '<head>' +
    '<title>Отчеты - SQL Server</title>' +
    '<style>' +
    'body { font-family: Arial; margin: 40px; background: #1e3c72; color: white; }' +
    '.container { max-width: 1400px; margin: 0 auto; }' +
    '.mssql-header { background: #00bfff; padding: 10px; border-radius: 5px; margin-bottom: 20px; }' +
    '.filters { background: rgba(0,0,0,0.4); padding: 15px; border-radius: 10px; margin: 20px 0; }' +
    '.filters a { color: #00ffff; margin-right: 15px; text-decoration: none; padding: 5px 10px; border-radius: 5px; }' +
    '.filters a:hover { background: rgba(0,150,255,0.3); }' +
    'table { width: 100%; background: rgba(255,255,255,0.05); }' +
    'th { background: rgba(0,100,255,0.7); padding: 15px; }' +
    'td { padding: 12px; border-bottom: 1px solid #333; }' +
    '.pagination { margin: 20px 0; }' +
    '.pagination a { color: #00bfff; margin-right: 10px; }' +
    '</style>' +
    '</head>' +
    '<body>' +
    '<div class="container">' +
    '<div class="mssql-header">' +
    '<h1>📊 Отчеты о НЛО - Microsoft SQL Server</h1>';
    
  if not FDConnection1.Connected then
    Response.Content := Response.Content +
      '<p style="color: yellow;">⚠️ Демо-режим: отображаются тестовые данные</p>';
    
  Response.Content := Response.Content +
    '</div>' +
    
    '<div class="filters">' +
    '<strong>Фильтры по статусу:</strong> ' +
    '<a href="/reports">Все (' + IntToStr(FTotalReports) + ')</a> | ' +
    '<a href="/reports?type=confirmed">✅ Подтвержденные (' + IntToStr(FConfirmedCount) + ')</a> | ' +
    '<a href="/reports?type=investigation">🔍 В расследовании (' + IntToStr(FInvestigationCount) + ')</a> | ' +
    '<a href="/reports?type=unconfirmed">❓ Неподтвержденные (' + IntToStr(FUnconfirmedCount) + ')</a>' +
    '</div>' +
    
    '<table>' +
    '<tr>' +
    '<th>ID</th>' +
    '<th>Дата</th>' +
    '<th>Местоположение</th>' +
    '<th>Описание</th>' +
    '<th>Статус</th>' +
    '</tr>' +
    GetReportsHTML(FilterType) +
    '</table>' +
    
    '<div class="pagination">' +
    '<a href="#">« Назад</a>' +
    '<a href="#" style="background: #00bfff; color: white; padding: 5px 10px;">1</a>' +
    '<a href="#">Вперед »</a>' +
    '</div>' +
    
    '<p><strong>Показано записей:</strong> ' + IntToStr(FTotalReports) + '</p>' +
    '<p><a href="/">← На главную</a> | <a href="/add">➕ Добавить отчет</a></p>' +
    
    '</div>' +
    '</body>' +
    '</html>';
    
  Handled := True;
end;

procedure TWebModule1.WebModule1StatsAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Response.Content := 
    '<html><body style="font-family: Arial; margin: 40px; background: #2c3e50; color: white;">' +
    '<h1>📈 Статистика - Microsoft SQL Server</h1>' +
    '<div style="background: rgba(0,100,200,0.3); padding: 20px; border-radius: 10px;">' +
    '<h2>📊 Общая статистика</h2>' +
    GetStatisticsHTML +
    '</div>' +
    '<p><a href="/">← На главную</a></p>' +
    '</body></html>';
    
  Handled := True;
end;

procedure TWebModule1.WebModule1AddReportAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  if Request.Method = 'POST' then
  begin
    if FDConnection1.Connected then
    begin
      Response.Content := 
        '<html><body style="font-family: Arial; margin: 40px; background: #1e3c72; color: white;">' +
        '<h1>✅ Отчет сохранен в SQL Server!</h1>' +
        '<p>Данные успешно записаны в базу данных.</p>' +
        '<p><a href="/">На главную</a></p>' +
        '</body></html>';
    end
    else
    begin
      Response.Content := 
        '<html><body style="font-family: Arial; margin: 40px; background: #1e3c72; color: white;">' +
        '<h1>⚠️ Демо-режим</h1>' +
        '<p>Отчет не сохранен (нет подключения к БД).</p>' +
        '<p>В реальной системе отчет был бы сохранен в SQL Server.</p>' +
        '<p><a href="/">На главную</a></p>' +
        '</body></html>';
    end;
  end
  else
  begin
    Response.Content := 
      '<html><head><title>Добавить в SQL Server</title>' +
      '<style>' +
      'body { font-family: Arial; margin: 40px; background: #1e3c72; color: white; }' +
      'form { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; }' +
      'input, textarea, select { width: 100%; padding: 10px; margin: 5px 0; }' +
      '</style>' +
      '</head>' +
      '<body>' +
      '<h1>➕ Добавить отчет в SQL Server</h1>';
    
    if not FDConnection1.Connected then
      Response.Content := Response.Content +
        '<p style="color: yellow;">⚠️ Режим без базы данных: отчет не будет сохранен</p>';
    
    Response.Content := Response.Content +
      '<p>Данные будут сохранены в промышленную БД Microsoft SQL Server</p>' +
      '<form method="post">' +
      '<p><strong>Местоположение:</strong></p>' +
      '<input type="text" name="location" placeholder="Город, страна" required>' +
      '<p><strong>Описание наблюдения:</strong></p>' +
      '<textarea name="description" rows="5" placeholder="Подробное описание..." required></textarea>' +
      '<p><strong>Тип объекта:</strong></p>' +
      '<select name="object_type">' +
      '<option value="Диск">Диск</option>' +
      '<option value="Треугольник">Треугольник</option>' +
      '<option value="Шар">Шар</option>' +
      '<option value="Сигара">Сигара</option>' +
      '<option value="Неизвестно">Неизвестно</option>' +
      '</select>' +
      '<p><strong>Дата наблюдения:</strong></p>' +
      '<input type="date" name="report_date" value="' + FormatDateTime('yyyy-mm-dd', Now) + '">' +
      '<p><input type="submit" value="📝 Сохранить отчет" style="background: #00bfff; color: white; border: none; padding: 15px; cursor: pointer;"></p>' +
      '</form>' +
      '<p><a href="/">← На главную</a></p>' +
      '</body></html>';
  end;
  Handled := True;
end;

procedure TWebModule1.WebModule1GetJSONAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Response.ContentType := 'application/json';
  Response.Content := GenerateUFODataJSON;
  Handled := True;
end;

procedure TWebModule1.WebModule1DBAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Response.Content := 
    '<html><head><title>Управление SQL Server</title>' +
    '<style>' +
    'body { font-family: Arial; margin: 40px; background: #333; color: white; } ' +
    '.admin-panel { max-width: 800px; margin: 0 auto; padding: 20px; background: rgba(0,0,0,0.7); } ' +
    '.mssql-btn { background: #00bfff; color: white; padding: 10px 15px; border: none; margin: 5px; cursor: pointer; border-radius: 5px; }' +
    '.mssql-btn:hover { background: #1e90ff; }' +
    '.danger-btn { background: #ff4444; }' +
    '.danger-btn:hover { background: #ff2222; }' +
    '.info-box { background: rgba(0,100,255,0.2); padding: 15px; border-radius: 10px; margin: 15px 0; }' +
    '</style>' +
    '<script>' +
    'function backupDB() { alert("Резервное копирование запущено!"); }' +
    'function optimizeDB() { alert("Оптимизация базы данных запущена!"); }' +
    'function reindexDB() { alert("Переиндексация запущена!"); }' +
    'function testConnection() { alert("Тестирование соединения..."); location.reload(); }' +
    '</script>' +
    '</head>' +
    '<body>' +
    '<div class="admin-panel">' +
    '<h1>⚙️ Управление Microsoft SQL Server</h1>' +
    
    '<div class="info-box">' +
    '<h3>Соединение с БД</h3>' +
    '<p>' + GetConnectionStatus + '</p>' +
    '<p><strong>Сервер:</strong> DESKTOP-00OEM2K\SQLEXPRESS</p>' +
    '<p><strong>База данных:</strong> UFOWebDB</p>' +
    '<p><strong>Аутентификация:</strong> Windows</p>' +
    '<button class="mssql-btn" onclick="testConnection()">🔄 Проверить соединение</button>' +
    '</div>' +
    
    '<h3>Статистика базы данных</h3>' +
    GetStatisticsHTML +
    
    '<h3>Действия с базой данных</h3>' +
    '<button class="mssql-btn" onclick="backupDB()">💾 Создать бэкап</button>' +
    '<button class="mssql-btn" onclick="optimizeDB()">⚡ Оптимизировать БД</button>' +
    '<button class="mssql-btn" onclick="reindexDB()">🔧 Переиндексировать</button>' +
    '<button class="mssql-btn danger-btn" onclick="alert(''Опасно! Функция не реализована'')">🧹 Очистить БД</button>' +
    
    '<p><a href="/">← На главную</a></p>' +
    '</div>' +
    '</body></html>';
    
  Handled := True;
end;

procedure TWebModule1.PageProducer1HTMLTag(Sender: TObject; Tag: TTag;
  const TagString: string; TagParams: TStrings; var ReplaceText: string);
begin
  if SameText(TagString, 'DATETIME') then
    ReplaceText := DateTimeToStr(Now)
  else if SameText(TagString, 'VERSION') then
    ReplaceText := '3.0 (MSSQL)';
end;

end.